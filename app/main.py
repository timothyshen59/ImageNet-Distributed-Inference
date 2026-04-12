# app/main.py
import numpy as np
import asyncio
import time

from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from contextlib import asynccontextmanager
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from typing import List
from scipy.special import softmax

from app.inference import TritonInferenceSession
from app.preprocess import resize, normalize_batch, _POOL
from app.metrics import REQUEST_LATENCY, REQUEST_COUNT
from app.inference_legacy import LegacyViTInferenceSession
from app.batching import Batcher

session = TritonInferenceSession()

legacy_session = LegacyViTInferenceSession()
legacy_batcher = Batcher(legacy_session)

@asynccontextmanager
async def lifespan(app: FastAPI):
    legacy_task = asyncio.create_task(legacy_batcher.run())
    yield
    legacy_task.cancel()

app = FastAPI(lifespan=lifespan)

# Triton Endpoint
@app.post("/inference/v2")
async def infer(files: List[UploadFile] = File(...)):
    start = time.time()

    try:
        img_bytes_list = await asyncio.gather(*[f.read() for f in files])

        loop = asyncio.get_event_loop()
        imgs = await asyncio.gather(*[
            loop.run_in_executor(_POOL, resize, b)
            for b in img_bytes_list
        ])

        batch = np.stack(imgs, axis=0)
        batch = normalize_batch(batch)
 
        results = await session.async_run(batch)


        probs = softmax(results, axis=1)
        indices = np.argmax(probs, axis=1)
        confidences = np.max(probs, axis=1)

        REQUEST_COUNT.labels(status="success").inc()

        return {
            "predictions": [
                {
                    "filename": files[i].filename,
                    "predicted_class": int(indices[i]),
                    "confidence": round(float(confidences[i]), 4)
                }
                for i in range(len(files))
            ]
        }

    except Exception as e:
        REQUEST_COUNT.labels(status="error").inc()
        raise e

    finally:
        REQUEST_LATENCY.observe(time.time() - start)

# Legacy Endpoint
@app.post("/inference/v1")
async def infer_legacy(files: List[UploadFile] = File(...)):
    start = time.time()

    try:
        img_bytes_list = await asyncio.gather(*[f.read() for f in files])
        tensors = [preprocess(b) for b in img_bytes_list]
        results = await asyncio.gather(*[legacy_batcher.infer(t) for t in tensors])

        probs = softmax(np.stack(results), axis=1)
        indices = np.argmax(probs, axis=1)
        confidences = np.max(probs, axis=1)

        REQUEST_COUNT.labels(status="success").inc()

        return {
            "predictions": [
                {
                    "filename": files[i].filename,
                    "predicted_class": int(indices[i]),
                    "confidence": round(float(confidences[i]), 4)
                }
                for i in range(len(files))
            ]
        }

    except Exception as e:
        REQUEST_COUNT.labels(status="error").inc()
        raise e

    finally:
        REQUEST_LATENCY.observe(time.time() - start)

#Prometheus Metrics
@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/health")
async def health():
    return {"status": "ok"}

