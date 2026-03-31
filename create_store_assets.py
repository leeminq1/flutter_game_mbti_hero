import os
import glob
from PIL import Image, ImageFilter

SRC_DIR = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\STORE_SCRINSHOT"
ICON_SRC = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\icon\app_icon.png"
OUT_DIR = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing"

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def create_icon():
    out_path = os.path.join(OUT_DIR, "app_icon_512.png")
    if os.path.exists(ICON_SRC):
        img = Image.open(ICON_SRC)
        img = img.resize((512, 512), Image.Resampling.LANCZOS)
        img.save(out_path, "PNG")
        print(f"Created App Icon: {out_path}")
    else:
        print("App Icon not found!")

def make_screenshot(src_path, dest_path, target_size=(1080, 1920)):
    # Aspect fill crop
    img = Image.open(src_path)
    src_w, src_h = img.size
    ratio_w = target_size[0] / src_w
    ratio_h = target_size[1] / src_h
    scale = max(ratio_w, ratio_h)
    new_w = int(src_w * scale)
    new_h = int(src_h * scale)
    
    img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center crop
    left = (new_w - target_size[0]) / 2
    top = (new_h - target_size[1]) / 2
    right = (new_w + target_size[0]) / 2
    bottom = (new_h + target_size[1]) / 2
    
    img_cropped = img_resized.crop((left, top, right, bottom))
    img_cropped = img_cropped.convert("RGB")
    img_cropped.save(dest_path, "JPEG", quality=95)
    print(f"Created Screenshot: {dest_path}")

def make_feature_graphic(src_path):
    out_path = os.path.join(OUT_DIR, "feature_graphic.jpg")
    target_size = (1024, 500)
    
    img = Image.open(src_path).convert("RGB")
    src_w, src_h = img.size
    bg_scale = target_size[0] / src_w
    bg_new_w, bg_new_h = int(src_w * bg_scale), int(src_h * bg_scale)
    bg = img.resize((bg_new_w, bg_new_h), Image.Resampling.LANCZOS)
    
    top = (bg_new_h - target_size[1]) // 2
    bg_cropped = bg.crop((0, top, target_size[0], top + target_size[1]))
    bg_blurred = bg_cropped.filter(ImageFilter.GaussianBlur(15))
    
    bg_dark = bg_blurred.point(lambda p: p * 0.7)
    
    fg_h = 460
    fg_scale = fg_h / src_h
    fg_w = int(src_w * fg_scale)
    fg = img.resize((fg_w, fg_h), Image.Resampling.LANCZOS)
    
    start_x = (target_size[0] - fg_w) // 2
    start_y = (target_size[1] - fg_h) // 2
    
    bg_dark.paste(fg, (start_x, start_y))
    bg_dark.save(out_path, "JPEG", quality=95)
    print(f"Created Feature Graphic: {out_path}")

def main():
    ensure_dir(OUT_DIR)
    
    phone_dir = os.path.join(OUT_DIR, "phone")
    tab7_dir = os.path.join(OUT_DIR, "tablet_7")
    tab10_dir = os.path.join(OUT_DIR, "tablet_10")
    
    ensure_dir(phone_dir)
    ensure_dir(tab7_dir)
    ensure_dir(tab10_dir)
    
    create_icon()
    
    valid_exts = [".jpg", ".jpeg", ".png"]
    files = [f for f in glob.glob(os.path.join(SRC_DIR, "*.*")) if os.path.splitext(f)[1].lower() in valid_exts]
    files.sort()
    
    if not files:
        print("No screenshots found.")
        return
        
    make_feature_graphic(files[1]) # Use second image for banner just for variety
    
    for i in range(min(3, len(files))):
        dest = os.path.join(phone_dir, f"phone_{i+1}.jpg")
        make_screenshot(files[i], dest)
        
    for i in range(min(5, len(files))):
        idx = (i + 3) % len(files)
        dest = os.path.join(tab7_dir, f"tab7_{i+1}.jpg")
        make_screenshot(files[idx], dest)
        
    for i in range(min(5, len(files))):
        idx = (i + 8) % len(files)
        dest = os.path.join(tab10_dir, f"tab10_{i+1}.jpg")
        make_screenshot(files[idx], dest)
        
    print("All assets successfully generated to assets/store_listing!")

if __name__ == "__main__":
    main()
