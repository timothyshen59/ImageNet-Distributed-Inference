#app/ inference.py

import onnxruntime as ort 
import tritonclient.grpc as grpcclient
import numpy as np 
import os 
from pathlib import Path 

class TritonInferenceSession: 
    def __init__(self, url: str = "triton:8001"): 
        self.client = grpcclient.InferenceServerClient(url=url)
        self.model_name = "vit_int8"
    
    def run(self, batch: np.ndarray) -> np.ndarray: 
        inputs = [grpcclient.InferInput("input", batch.shape, "FP32")]
        inputs[0].set_data_from_numpy(batch)
        
        outputs = [grpcclient.InferRequestedOutput("output")]
        
        response = self.client.infer(
            model_name=self.model_name,
            inputs=inputs,
            outputs=outputs    
        )
        
        result = response.as_numpy("output")
        
        return result
    

#Test 
if __name__ == "__main__":
    session = TritonInferenceSession()
    dummy = np.random.randn(1, 3, 224, 224).astype(np.float32)
    result = session.run(dummy)
    print(f"Output shape: {result.shape}")        
    print(f"Predicted class: {np.argmax(result)}") 