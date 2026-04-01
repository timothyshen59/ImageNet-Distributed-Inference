#app/main.py 

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
from app.preprocess import preprocess
from app.metrics import REQUEST_LATENCY, REQUEST_COUNT  

session = TritonInferenceSession() 

@asynccontextmanager
async def lifespan(app: FastAPI): 
    yield                        # Triton manages its own lifecycle

app = FastAPI(lifespan=lifespan) 

@app.post("/inference")
async def infer(files: List[UploadFile] = File(...)):
    start = time.time()  
    
    try: 
        img_bytes_list = await asyncio.gather(*[f.read() for f in files])
        
        tensors = [preprocess(b) for b in img_bytes_list]
        batch = np.concatenate(tensors, axis=0)          # (N, 3, 224, 224)
        
        loop = asyncio.get_event_loop()
        results = await loop.run_in_executor(None, session.run, batch)                 # Triton handles batching
        
        probs = softmax(results, axis=1)                 # (N, 1000)
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
        
@app.get("/metrics")
async def metrics(): 
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/health")
async def health(): 
    return {"status": "ok"}
