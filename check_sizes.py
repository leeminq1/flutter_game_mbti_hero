import os
from PIL import Image

def main():
    for d in ['characters', 'enemies']:
        path = os.path.join('assets', 'images', d)
        if not os.path.exists(path): continue
        for f in os.listdir(path):
            if f.endswith('.png'):
                img = Image.open(os.path.join(path, f))
                print(f"{d}/{f}: {img.size}")

if __name__ == '__main__':
    main()
