import os
import glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC_DIR = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone"
files = glob.glob(os.path.join(SRC_DIR, "Screenshot_*.jpg"))
files.sort()

OUT_PHONE = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone"
OUT_TAB7 = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\tablet_7"
OUT_TAB10 = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\tablet_10"
OUT_FEATURE = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing"

PROMO_TEXTS_PHONE = [
    "각양각색 MBTI 영웅들!\n여러분의 유형은?",
    "상상 초월 스킬 트리를\n완성해보세요!",
    "퇴근을 위한 사투,\n이제 시작됩니다!"
]

PROMO_TEXTS_TAB7 = [
    "통쾌한 핵앤슬래시의 재미!\n스트레스를 날리세요",
    "개성 넘치는 16가지\nMBTI 영웅 라인업!",
    "매 판 달라지는\n로그라이크 스킬 성장",
    "직장 빌런들을 심판할\n강력한 궁극기 전개!",
    "위기의 순간,\n한 방 역전을 노려라!"
]

PROMO_TEXTS_TAB10 = [
    "시원한 직장인 서바이벌,\n지금 다운로드하세요!",
    "압도적인 타격감,\n손끝에서 터지는 쾌감",
    "최상의 빌드를 갖춰\n끝까지 생존하라!",
    "나만의 MBTI로\n모든 빌런들을 압도하라",
    "칼퇴를 향한\n화려한 전투 액션!"
]

def get_font(size):
    font_path = "C:\\Windows\\Fonts\\malgunbd.ttf"
    if not os.path.exists(font_path):
        font_path = "C:\\Windows\\Fonts\\malgun.ttf"
    try:
        return ImageFont.truetype(font_path, size)
    except:
        return ImageFont.load_default()

def create_promo_image(img_path, out_path, text):
    font = get_font(75)
    canvas = Image.new("RGB", (1080, 1920), color=(15, 15, 23))
    screenshot = Image.open(img_path).convert("RGB")
    
    target_w = 900
    scale = target_w / screenshot.size[0]
    target_h = int(screenshot.size[1] * scale)
    scr_resized = screenshot.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    cut_h = min(1450, target_h)
    top = (target_h - cut_h) // 2
    scr_cropped = scr_resized.crop((0, top, target_w, top + cut_h))
    
    border = 6
    framed = Image.new("RGB", (target_w + border*2, cut_h + border*2), color=(255, 255, 255))
    framed.paste(scr_cropped, (border, border))
    
    bg = screenshot.resize((1080, 1920), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(35)).point(lambda p: p * 0.45)
    canvas.paste(bg, (0,0))
    
    paste_y = 1920 - framed.size[1] - 80
    paste_x = (1080 - framed.size[0]) // 2
    canvas.paste(framed, (paste_x, paste_y))
    
    draw = ImageDraw.Draw(canvas)
    bbox = draw.textbbox((0, 0), text, font=font, align="center")
    text_w = bbox[2] - bbox[0]
    text_y = 110
    text_x = (1080 - text_w) / 2
    
    outline_color = (0,0,0)
    for ax in [-4,-2,0,2,4]:
        for ay in [-4,-2,0,2,4]:
            draw.multiline_text((text_x+ax, text_y+ay), text, font=font, fill=outline_color, align="center")
            
    draw.multiline_text((text_x, text_y), text, font=font, fill=(255, 240, 80), align="center")
    
    canvas.save(out_path, "JPEG", quality=95)
    print("Saved ->", out_path)

def create_cool_feature_graphic(img_path):
    canvas = Image.new("RGB", (1024, 500), color=(20,20,30))
    screenshot = Image.open(img_path).convert("RGB")
    
    bg_scale = 1024 / screenshot.size[0]
    bg_h = int(screenshot.size[1] * bg_scale)
    bg = screenshot.resize((1024, bg_h), Image.Resampling.LANCZOS)
    top = (bg_h - 500)//2
    bg = bg.crop((0, top, 1024, top+500)).filter(ImageFilter.GaussianBlur(25)).point(lambda p: p*0.4)
    canvas.paste(bg, (0,0))
    
    target_h = 440
    scale = target_h / screenshot.size[1]
    target_w = int(screenshot.size[0] * scale)
    scr_resized = screenshot.resize((target_w, target_h), Image.Resampling.LANCZOS)
    border = 6
    framed = Image.new("RGB", (target_w + border*2, target_h + border*2), color=(255,255,255))
    framed.paste(scr_resized, (border, border))
    
    paste_x = 1024 - framed.size[0] - 40
    paste_y = (500 - framed.size[1]) // 2
    canvas.paste(framed, (paste_x, paste_y))
    
    draw = ImageDraw.Draw(canvas)
    title = "MBTI 히어로\n직장인 생존기"
    font_hero = get_font(85)
    tx = 60
    ty = 110
    for ax in [-4,-2,0,2,4]:
        for ay in [-4,-2,0,2,4]:
            draw.multiline_text((tx+ax, ty+ay), title, font=font_hero, fill=(0,0,0), align="left")
    draw.multiline_text((tx, ty), title, font=font_hero, fill=(255, 240, 50), align="left")
    
    sub = "스트레스 제로!\n통쾌한 서바이벌 액션!"
    font_sub = get_font(38)
    ty2 = ty + 210
    for ax in [-2,0,2]:
        for ay in [-2,0,2]:
            draw.multiline_text((tx+ax, ty2+ay), sub, font=font_sub, fill=(0,0,0), align="left")
    draw.multiline_text((tx, ty2), sub, font=font_sub, fill=(255,255,255), align="left")
    
    out = os.path.join(OUT_FEATURE, "feature_graphic.jpg")
    canvas.save(out, "JPEG", quality=98)
    print("Saved Feature Graphic ->", out)

def main():
    if not files:
        print("No screenshots found.")
        return
    
    os.makedirs(OUT_PHONE, exist_ok=True)
    os.makedirs(OUT_TAB7, exist_ok=True)
    os.makedirs(OUT_TAB10, exist_ok=True)
    
    create_cool_feature_graphic(files[6])  # Use a nice index for the cover
    
    for i in range(3):
        create_promo_image(files[i % len(files)], os.path.join(OUT_PHONE, f"promo_phone_{i+6}.jpg"), PROMO_TEXTS_PHONE[i])
        
    for i in range(5):
        create_promo_image(files[(i+3) % len(files)], os.path.join(OUT_TAB7, f"promo_tab7_{i+1}.jpg"), PROMO_TEXTS_TAB7[i])
        
    for i in range(5):
        create_promo_image(files[(i+8) % len(files)], os.path.join(OUT_TAB10, f"promo_tab10_{i+1}.jpg"), PROMO_TEXTS_TAB10[i])
        
if __name__ == "__main__":
    main()
