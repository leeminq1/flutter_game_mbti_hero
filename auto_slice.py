import os
import cv2
import numpy as np
from PIL import Image
from rembg import remove

def process_sheet(filepath, out_dir, prefix):
    print(f"Processing sheet: {filepath}")
    if not os.path.exists(filepath):
        print("File not found")
        return
        
    os.makedirs(out_dir, exist_ok=True)
    
    # 1. Remove background
    with open(filepath, 'rb') as f:
        img_bytes = remove(f.read())
    
    # Load into PIL, then numpy
    pil_img = Image.open(import_io_bytes(img_bytes)).convert("RGBA")
    
    img = np.array(pil_img)
    
    # 2. Extract alpha channel for contour detection
    alpha = img[:, :, 3]
    
    # find contours
    contours, _ = cv2.findContours(alpha, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    print(f"Found {len(contours)} potential items.")
    
    # Sort contours by x position (left to right) if possible, or just by size
    contours = sorted(contours, key=cv2.contourArea, reverse=True)
    
    count = 0
    for i, c in enumerate(contours):
        x, y, w, h = cv2.boundingRect(c)
        # Filter out tiny noise
        if w < 16 or h < 16:
            continue
            
        # Crop the image
        cropped = img[y:y+h, x:x+w]
        
        # Save
        out_path = os.path.join(out_dir, f"{prefix}_{count}.png")
        Image.fromarray(cropped).save(out_path)
        print(f"Saved {out_path} ({w}x{h})")
        count += 1
        
        if count >= 20: # hard limit just in case of crazy noise
            break

def import_io_bytes(b):
    import io
    return io.BytesIO(b)

if __name__ == '__main__':
    # Process enemies
    process_sheet(
        r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\enemies\enemies_raw.png',
        r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\enemies',
        'enemy'
    )
    
    # Process icons
    process_sheet(
        r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\ui\icons.png',
        r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\ui\extracted',
        'icon'
    )
    
    # Process obstacles
    process_sheet(
        r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\maps\map_obstacles.png',
        r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\maps\obstacles',
        'obstacle'
    )
    
    # For map tile, just crop a 256x256 center chunk to use as seamless background
    try:
        tile_path = r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\maps\map_tile.png'
        if os.path.exists(tile_path):
            img = Image.open(tile_path)
            # just crop the center 512x512
            w, h = img.size
            cx, cy = w//2, h//2
            cropped_tile = img.crop((cx-256, cy-256, cx+256, cy+256))
            cropped_tile.save(r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\maps\bg_tile.png')
            print("Saved map tile bg_tile.png")
    except Exception as e:
        print("Error map tile:", e)

