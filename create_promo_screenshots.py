import os
import glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW_SCREENSHOTS_DIR = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images\STORE_SCRINSHOT"
OUT_DIR = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone"

PROMO_TEXTS = [
    "쏟아지는 직장 스트레스,\n시원하게 날려버리세요!",
    "16가지 MBTI 특성 반영!\n나만의 성격으로 플레이",
    "쉴 틈 없이 몰려오는\n사무실 빌런들을 물리쳐라!",
    "자유로운 스킬 조합!\n나만의 로그라이크 빌드",
    "위기의 순간, 강력한\n궁극기로 통쾌한 한 방!"
]

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def create_promo_images():
    ensure_dir(OUT_DIR)
    
    font_path = "C:\\Windows\\Fonts\\malgunbd.ttf"
    if not os.path.exists(font_path):
        font_path = "C:\\Windows\\Fonts\\malgun.ttf"
    
    try:
        font_large = ImageFont.truetype(font_path, 75)
    except:
        font_large = ImageFont.load_default()
        print("Korean font not found, text might be broken.")

    raw_files = [f for f in glob.glob(os.path.join(RAW_SCREENSHOTS_DIR, "*.*")) if f.lower().endswith(('png', 'jpg', 'jpeg'))]
    raw_files.sort()
    
    if len(raw_files) < 5:
        print("Not enough raw screenshots.")
        return

    for i in range(5):
        canvas = Image.new("RGB", (1080, 1920), color=(20, 20, 30))
        
        idx = (i + 5) % len(raw_files)
        screenshot = Image.open(raw_files[idx]).convert("RGB")
        
        target_w = 900
        scale = target_w / screenshot.size[0]
        target_h = int(screenshot.size[1] * scale)
        scr_resized = screenshot.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        cut_h = 1450
        scr_cropped = scr_resized.crop((0, (target_h-cut_h)//2, target_w, (target_h+cut_h)//2))
        
        border_size = 6
        scr_with_border = Image.new("RGB", (target_w + border_size*2, cut_h + border_size*2), color=(255, 255, 255))
        scr_with_border.paste(scr_cropped, (border_size, border_size))
        
        bg = screenshot.resize((1080, 1920), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(35)).point(lambda p: p * 0.45)
        canvas.paste(bg, (0,0))
        
        paste_y = 1920 - scr_with_border.size[1] - 80
        paste_x = (1080 - scr_with_border.size[0]) // 2
        canvas.paste(scr_with_border, (paste_x, paste_y))
        
        draw = ImageDraw.Draw(canvas)
        text = PROMO_TEXTS[i]
        
        bbox = draw.textbbox((0, 0), text, font=font_large, align="center")
        text_w = bbox[2] - bbox[0]
        text_y = 120
        text_x = (1080 - text_w) / 2
        
        outline_color = (0, 0, 0)
        for adj_x in [-4, -2, 0, 2, 4]:
            for adj_y in [-4, -2, 0, 2, 4]:
                draw.multiline_text((text_x+adj_x, text_y+adj_y), text, font=font_large, fill=outline_color, align="center")
        
        draw.multiline_text((text_x, text_y), text, font=font_large, fill=(255, 230, 80), align="center")
        
        out_path = os.path.join(OUT_DIR, f"promo_phone_{i+1}.jpg")
        canvas.save(out_path, "JPEG", quality=95)
        print(f"Saved {out_path}")

if __name__ == "__main__":
    create_promo_images()
