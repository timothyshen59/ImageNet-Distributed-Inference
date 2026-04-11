# app/preprocess.py 
from PIL import Image 
import cv2
import numpy as np 
import io 
from concurrent.futures import ThreadPoolExecutor
import os

_POOL = ThreadPoolExecutor(max_workers=os.cpu_count())
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

_SCALE = (1.0 / 255.0 / np.array([0.229, 0.224, 0.225], dtype=np.float32))
_SHIFT = (-np.array([0.485, 0.456, 0.406], dtype=np.float32) / np.array([0.229, 0.224, 0.225], dtype=np.float32))


def resize(image_bytes: bytes) -> np.ndarray: 
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    img = cv2.resize(img, (224, 224), interpolation=cv2.INTER_LINEAR)

    return img[:,:, ::-1]

def normalize_batch(batch: np.ndarray) -> np.ndarray:
    out = batch.astype(np.float32)
    out *= _SCALE[np.newaxis, np.newaxis, np.newaxis, :]
    out += _SHIFT[np.newaxis, np.newaxis, np.newaxis, :]
    return np.ascontiguousarray(out.transpose(0, 3, 1, 2))
    


# def preprocess(image_bytes: bytes) -> np.ndarray: 
#     try: 
#         img = jpeg.decode(image_bytes, pixel_format = TJPF_RGB)
        
#     except Exception: 
#         img = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"), dtype=np.uint8)
        
#     img = Image.fromarray(img).resize((256,256), Image.BILINEAR)
#     img = np.array(img, dtype=np.float32)
    
#     left = (256-224) // 2 
#     img = img[left:left+224, left:left+224]
    
#     img = (img / 255.0 - MEAN) /STD 
#     img = img.transpose(2,0,1)
    
#     return img[np.newaxis].astype(np.float32)
    
    