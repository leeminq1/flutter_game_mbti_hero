import os
import io
from PIL import Image
from rembg import remove
import numpy as np

def crop_sprites(img):
    # Convert to RGBA numpy array
    np_img = np.array(img)
    alpha = np_img[:, :, 3]
    
    # Find active pixels
    y_idx, x_idx = np.where(alpha > 0)
    
    if len(y_idx) == 0 or len(x_idx) == 0:
        return img # Empty image
        
    ymin, ymax = y_idx.min(), y_idx.max()
    xmin, xmax = x_idx.min(), x_idx.max()
    
    # Crop to content
    cropped = img.crop((xmin, ymin, xmax, ymax))
    
    # In these AI generated images for game assets, they usually have 4 frames side-by-side or a grid.
    # For now, let's just make sure the cropped size is a power of 2 or fits nicely 
    # without returning a huge 2816x1536 canvas
    return cropped

def process_image(filepath, output_path):
    print(f"Processing: {filepath}")
    try:
        # Load image
        with open(filepath, 'rb') as i:
            input_bytes = i.read()
            
        # Remove background using rembg
        print("  Removing background...")
        output_bytes = remove(input_bytes)
        img = Image.open(io.BytesIO(output_bytes)).convert("RGBA")
        
        # Crop tight around the sprites
        print("  Cropping bounds...")
        img_cropped = crop_sprites(img)
        
        # Resize if still too large (e.g., limit height to something reasonable like 256 for sprites)
        MAX_HEIGHT = 256
        w, h = img_cropped.size
        # if h > MAX_HEIGHT:
        #     ratio = MAX_HEIGHT / float(h)
        #     new_w = int(float(w) * ratio)
        #     img_cropped = img_cropped.resize((new_w, MAX_HEIGHT), Image.Resampling.LANCZOS)
            
        print(f"  Final size: {img_cropped.size}")
        
        # Save output
        img_cropped.save(output_path, 'PNG')
        print(f"  Saved to: {output_path}")
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

def main():
    root_dir = r'c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images'
    folders = ['characters', 'enemies']
    
    for folder in folders:
        folder_path = os.path.join(root_dir, folder)
        if not os.path.exists(folder_path): continue
        
        for file in os.listdir(folder_path):
            if file.endswith('.png') and not file.endswith('_processed.png'):
                in_path = os.path.join(folder_path, file)
                # Save as same name to overwrite, or append _processed to compare?
                # Overwriting to apply directly to game.
                process_image(in_path, in_path)

if __name__ == '__main__':
    main()
