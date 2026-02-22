import os
import cv2
import numpy as np
from PIL import Image
from rembg import remove

def process_boss(in_path, out_path):
    print(f"Processing boss: {in_path}")
    if not os.path.exists(in_path):
        print("Not found")
        return
        
    with open(in_path, 'rb') as f:
        img_bytes = remove(f.read())
        
    pil_img = Image.open(import_io_bytes(img_bytes)).convert("RGBA")
    img = np.array(pil_img)
    alpha = img[:, :, 3]
    
    contours, _ = cv2.findContours(alpha, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        print("No contours found")
        return
        
    # Get the largest contour (the boss)
    c = max(contours, key=cv2.contourArea)
    x, y, w, h = cv2.boundingRect(c)
    
    cropped = img[y:y+h, x:x+w]
    Image.fromarray(cropped).save(out_path)
    print(f"Saved {out_path}")

def import_io_bytes(b):
    import io
    return io.BytesIO(b)

if __name__ == '__main__':
    base_dir = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\enemies"
    for i in range(1, 4):
        process_boss(os.path.join(base_dir, f"boss_{i}.png"), os.path.join(base_dir, f"boss_{i}_proc.png"))
