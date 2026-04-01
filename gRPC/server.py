import asyncio 
import numpy as np 
import grpc 

from gRPC import inference_pb2          
from gRPC import inference_pb2_grpc 
from grpc_reflection.v1alpha import reflection

from app.inference import TritonInferenceSession
from app.batching import Batcher 




class InferenceServicer(inference_pb2_grpc.InferenceServiceServicer): 
    def __init__(self, batcher: Batcher): 
        self.batcher = batcher 
    
    async def Infer(self, request, context): 
        image = np.array(list(request.data), dtype = np.float32).reshape(3,224,224)
        
        result = await self.batcher.infer(image)
        
        return inference_pb2.InferResponse(
            logits=result.tolist(),
            predicted_classes=int(np.argmax(result))
        )
        


async def serve(batcher: Batcher): 
        server = grpc.aio.server() 
        
        inference_pb2_grpc.add_InferenceServiceServicer_to_server( 
            InferenceServicer(batcher), server
        )
        
        
        SERVICE_NAMES = (
            inference_pb2.DESCRIPTOR.services_by_name['InferenceService'].full_name,
            reflection.SERVICE_NAME,
        )
        reflection.enable_server_reflection(SERVICE_NAMES, server)
        
        server.add_insecure_port("[::]:50051")
        
        await server.start()
        print("gRPC server listening on port 50051") 
        await server.wait_for_termination()
        
        
        