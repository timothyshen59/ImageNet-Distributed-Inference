# app/preprocess.py 
from turbojpeg import TurboJPEG, TJPF_RGB 
from PIL import Image 
import numpy as np 
import io 

jpeg = TurboJPEG() 

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

def preprocess(image_bytes: bytes) -> np.ndarray: 
    try: 
        img = jpeg.decode(image_bytes, pixel_format = TJPF_RGB)
    except Exception: 
        img = np.array(Image.open(io.BytesIO(image_bytes)).convert("RGB"), dtype=np.uint8)
        
    img = Image.fromarray(img).resize((256,256), Image.BILINEAR)
    img = np.array(img, dtype=np.float32)
    
    left = (256-224) // 2 
    img = img[left:left+224, left:left+224]
    
    img = (img / 255.0 - MEAN) /STD 
    img = img.transpose(2,0,1)
    
    return img[np.newaxis].astype(np.float32)
    
    