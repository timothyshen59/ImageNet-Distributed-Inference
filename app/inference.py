#app/inference.py

import tritonclient.grpc.aio as grpcclient_aio
import tritonclient.grpc as grpcclient
import numpy as np 

class TritonInferenceSession: 
    def __init__(self, url: str = "triton:8001", model_name: str = "vit_int8"):
        self.client = grpcclient.InferenceServerClient(url=url)  # keep sync for health checks
        self.async_client = grpcclient_aio.InferenceServerClient(url=url)
        self.model_name = model_name
    
    def run(self, batch: np.ndarray) -> np.ndarray: 
        inputs = [grpcclient.InferInput("input", batch.shape, "FP32")]
        inputs[0].set_data_from_numpy(batch)
        outputs = [grpcclient.InferRequestedOutput("output")]
        response = self.client.infer(
            model_name=self.model_name,
            inputs=inputs,
            outputs=outputs    
        )
        return response.as_numpy("output")

    async def async_run(self, batch: np.ndarray) -> np.ndarray:
        inputs = [grpcclient_aio.InferInput("input", batch.shape, "FP32")]
        inputs[0].set_data_from_numpy(batch)
        outputs = [grpcclient_aio.InferRequestedOutput("output")]
        response = await self.async_client.infer(
            model_name=self.model_name,
            inputs=inputs,
            outputs=outputs    
        )
        return response.as_numpy("output")


if __name__ == "__main__":
    session = TritonInferenceSession()
    dummy = np.random.randn(1, 3, 224, 224).astype(np.float32)
    result = session.run(dummy)
    print(f"Output shape: {result.shape}")        
    print(f"Predicted class: {np.argmax(result)}")