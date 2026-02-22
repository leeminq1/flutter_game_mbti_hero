import cv2
import numpy as np
import os
from rembg import remove

def imread_unicode(path):
    stream = open(path, "rb")
    bytes = bytearray(stream.read())
    nparray = np.asarray(bytes, dtype=np.uint8)
    return cv2.imdecode(nparray, cv2.IMREAD_UNCHANGED)

def process():
    input_path = 'assets/images/effects/캐릭터별 스킬_이펙트 모음.png'.encode('utf-8').decode('utf-8')
    if not os.path.exists(input_path):
        print("File not found")
        return

    img = imread_unicode(input_path)
    print(f"Loaded image {img.shape}")
    
    is_success, buffer = cv2.imencode(".png", img)
    if not is_success: return
    
    print("Running rembg on full image...")
    out_bytes = remove(buffer.tobytes())
    out_np = np.frombuffer(out_bytes, np.uint8)
    bg_removed = cv2.imdecode(out_np, cv2.IMREAD_UNCHANGED)
    
    print(f"Background removed. New shape: {bg_removed.shape}")
    
    alpha = bg_removed[:, :, 3]
    _, thresh = cv2.threshold(alpha, 10, 255, cv2.THRESH_BINARY)
    
    kernel = np.ones((15, 15), np.uint8)
    thresh = cv2.dilate(thresh, kernel, iterations=2)
    
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    icons = []
    print(f"Total contours found: {len(contours)}")
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if w > 30 and h > 30: 
            if w < 1000 and h < 1000:
                icons.append((x, y, w, h))
            else:
                print(f"Skipping too large contour: {w}x{h}")
                
    icons.sort(key=lambda b: (b[1] // 150, b[0]))
    print(f"Found {len(icons)} potential icons.")
    
    os.makedirs('assets/images/effects/extracted', exist_ok=True)
    
    for idx, (x, y, w, h) in enumerate(icons):
        pad = 20
        x1 = max(0, x - pad)
        y1 = max(0, y - pad)
        x2 = min(bg_removed.shape[1], x + w + pad)
        y2 = min(bg_removed.shape[0], y + h + pad)
        
        roi = bg_removed[y1:y2, x1:x2]
        
        out_path = f'assets/images/effects/extracted/icon_{idx}.png'
        is_success, im_buf_arr = cv2.imencode(".png", roi)
        im_buf_arr.tofile(out_path)
        print(f"Saved {out_path} ({w}x{h})")

process()
