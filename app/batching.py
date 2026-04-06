# app/batching.py

import asyncio 
import numpy as np 
from concurrent.futures import ThreadPoolExecutor
from app.inference import TritonInferenceSession
from app.metrics import BATCH_SIZE, QUEUE_DEPTH 

MAX_BATCH_SIZE = 16 
FLUSH_TIMEOUT = 0.10

class Batcher: 
    def __init__(self, session: TritonInferenceSession): 
        self.session = session 
        self.queue = asyncio.Queue() 
        self.executor = ThreadPoolExecutor(max_workers=1)
        
    async def infer(self, image: np.ndarray) -> np.ndarray: 
        loop = asyncio.get_event_loop() 
        future = loop.create_future() 
        await self.queue.put((image,future))
        QUEUE_DEPTH.set(self.queue.qsize())
        return await future 
    
    async def run(self): 
        loop = asyncio.get_event_loop()
        
        while True: 
            items = [] 
            
            try: 
                first = await asyncio.wait_for(self.queue.get(), 
                        timeout=FLUSH_TIMEOUT)
                
                items.append(first)
                
                while len(items) < MAX_BATCH_SIZE and not self.queue.empty(): 
                    items.append(self.queue.get_nowait())
                    
            except asyncio.TimeoutError: 
                continue 
            
            BATCH_SIZE.observe(len(items))
            QUEUE_DEPTH.set(self.queue.qsize())
             
            batch = np.concatenate([img for img, _ in items], axis=0)
            results = await loop.run_in_executor(
                self.executor, self.session.run, batch
            )
            
            for i, (_, future) in enumerate(items): 
                future.set_result(results[i])
                
                
                