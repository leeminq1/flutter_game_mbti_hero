import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

# Images requested by user
IMAGE_FILES = [
    r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone\phone_3.jpg",
    r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone\Screenshot_20260331_210332.jpg",
    r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone\Screenshot_20260331_210258.jpg",
    r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone\Screenshot_20260331_210214.jpg",
    r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\phone\Screenshot_20260331_210133.jpg"
]

OUT_PATH = r"c:\Users\min21\Desktop\flutter_grame\flutter_game\assets\store_listing\feature_graphic.jpg"

def get_font(size):
    font_path = "C:\\Windows\\Fonts\\malgunbd.ttf"
    if not os.path.exists(font_path):
        font_path = "C:\\Windows\\Fonts\\malgun.ttf"
    try:
        return ImageFont.truetype(font_path, size)
    except:
        return ImageFont.load_default()

def process_screenshot(path, target_w=190, target_h=370):
    """ Loads, rescales to fill height, and center crops to exact target size. """
    img = Image.open(path).convert("RGB")
    src_w, src_h = img.size
    
    # Scale to fill height
    scale = target_h / src_h
    new_w = int(src_w * scale)
    new_h = target_h
    
    # If width is too small to fill target_w, scale to fill width instead
    if new_w < target_w:
        scale = target_w / src_w
        new_w = target_w
        new_h = int(src_h * scale)
        
    img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center crop
    left = (new_w - target_w) // 2
    top = (new_h - target_h) // 2
    cropped = img_resized.crop((left, top, left + target_w, top + target_h))
    
    # Create white border
    border = 4
    framed = Image.new("RGBA", (target_w + border*2, target_h + border*2), (255, 255, 255, 255))
    framed.paste(cropped, (border, border))
    
    return framed

def create_shadow_image(image_rgba, offset=(0,0), blur_radius=8, shadow_color=(0,0,0,180)):
    """ Creates a drop shadow layer for the given RGBA image """
    shadow = Image.new("RGBA", image_rgba.size, (0,0,0,0))
    # Fill shadow with solid color
    alpha = image_rgba.split()[3]
    shadow.paste(shadow_color, mask=alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur_radius))
    return shadow

def build_cooler_feature_graphic():
    canvas = Image.new("RGB", (1024, 500), color=(10, 10, 18))
    
    # Create an exciting blurred background from the center image
    bg_src = Image.open(IMAGE_FILES[2]).convert("RGB")
    bg_scale = 1024 / bg_src.size[0]
    bg_h = int(bg_src.size[1] * bg_scale)
    bg = bg_src.resize((1024, bg_h), Image.Resampling.LANCZOS)
    top = (bg_h - 500) // 2
    bg = bg.crop((0, top, 1024, top + 500))
    bg = bg.filter(ImageFilter.GaussianBlur(25)).point(lambda p: p * 0.5)
    canvas.paste(bg, (0, 0))
    
    # Create fanned out cards
    angles = [-14, -7, 0, 7, 14]
    
    # X spacing to center the 5 cards
    spacing = 175
    start_x = (1024 - (spacing * 4 + 190)) // 2  # about 72
    base_y = [85, 60, 45, 60, 85]
    
    # To properly composite RGBA over RGB, we need a transparent layer
    card_layer = Image.new("RGBA", (1024, 500), (0,0,0,0))
    
    for i in range(5):
        # Process and frame
        card = process_screenshot(IMAGE_FILES[i])
        
        # Rotate
        rotated_card = card.rotate(angles[i], Image.Resampling.BICUBIC, expand=True)
        
        rx = start_x + spacing * i
        ry = base_y[i]
        
        # Adjust position offset due to expansion from rotation
        offset_x = (rotated_card.size[0] - card.size[0]) // 2
        offset_y = (rotated_card.size[1] - card.size[1]) // 2
        
        final_x = rx - offset_x
        final_y = ry - offset_y
        
        # Create shadow layer
        shadow = create_shadow_image(rotated_card, blur_radius=8)
        
        # composite shadow then card
        # we can just paste onto card_layer
        card_layer.alpha_composite(shadow, dest=(final_x + 5, final_y + 10))
        card_layer.alpha_composite(rotated_card, dest=(final_x, final_y))
        
    canvas.paste(card_layer, (0,0), mask=card_layer.split()[3])
    
    # Draw Title and Subtitle
    draw = ImageDraw.Draw(canvas)
    
    # We will put the title bottom right or bottom center
    title = "MBTI 히어로: 직장인 생존기"
    sub = "스트레스를 박살내는 시원한 슈팅 서바이벌!"
    
    font_title = get_font(52)
    font_sub = get_font(24)
    
    # Title shadow / outline
    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    tx = (1024 - tw) // 2
    ty = 405
    
    outline_color = (0,0,0)
    for ax in [-3,-1,0,1,3]:
        for ay in [-3,-1,0,1,3]:
            draw.text((tx+ax, ty+ay), title, font=font_title, fill=outline_color)
            
    # Subtitle shadow / outline
    bbox2 = draw.textbbox((0, 0), sub, font=font_sub)
    tw2 = bbox2[2] - bbox2[0]
    tx2 = (1024 - tw2) // 2
    ty2 = ty + 60
    
    for ax in [-2,0,2]:
        for ay in [-2,0,2]:
            draw.text((tx2+ax, ty2+ay), sub, font=font_sub, fill=outline_color)
            
    # Fill texts
    draw.text((tx, ty), title, font=font_title, fill=(255, 230, 0))
    draw.text((tx2, ty2), sub, font=font_sub, fill=(255, 255, 255))
    
    canvas.save(OUT_PATH, "JPEG", quality=98)
    print("New Cooler Feature Graphic Created ->", OUT_PATH)

if __name__ == "__main__":
    build_cooler_feature_graphic()
