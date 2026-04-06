#app/inference_legacy.py

import onnxruntime as ort 
import numpy as np 
import os 
from pathlib import Path 

class LegacyViTInferenceSession: 
    def __init__ (self, model_path: str = "../model/vit_legacy.onnx"): 
        self.model_path = Path(__file__).parent.parent / "model" / "vit_legacy.onnx"
        
        opts = ort.SessionOptions()
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        opts.intra_op_num_threads = 1
        opts.inter_op_num_threads = 1              
        opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL

        opts.enable_mem_pattern = True
        opts.enable_cpu_mem_arena = True

        self.session = ort.InferenceSession( 
            self.model_path,
            providers=["CPUExecutionProvider"]                       
        )
        
    def run(self, batch: np.ndarray) -> np.ndarray: 
            
        outputs = self.session.run( 
            ["output"],
            {"input": batch}
        )
        result = outputs[0]
            
        return result 
    
    
if __name__ == "__main__":
    session = ViTInferenceSession()
    dummy = np.random.randn(1, 3, 224, 224).astype(np.float32)
    result = session.run(dummy)
    print(f"Output shape: {result.shape}")        
    print(f"Predicted class: {np.argmax(result)}") 