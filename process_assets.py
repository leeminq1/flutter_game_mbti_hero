import argparse
from collections import deque
from pathlib import Path

from PIL import Image


ROOT_DIR = Path(r"C:\Users\min21\Desktop\flutter_grame\flutter_game\assets\images")
DEFAULT_FOLDERS = ("characters", "enemies")
SUPPORTED_EXTENSIONS = {".png"}


def is_dark(pixel, threshold=14):
    r, g, b, a = pixel
    return a > 0 and r <= threshold and g <= threshold and b <= threshold


def is_light(pixel, threshold=245):
    r, g, b, a = pixel
    return a > 0 and r >= threshold and g >= threshold and b >= threshold


def remove_edge_background(img):
    rgba = img.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    visited = [[False] * width for _ in range(height)]
    queue = deque()

    def enqueue(x, y):
        if visited[y][x]:
            return
        pixel = pixels[x, y]
        if is_dark(pixel) or is_light(pixel):
            visited[y][x] = True
            queue.append((x, y, "dark" if is_dark(pixel) else "light"))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y, bg_type = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)

        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx = x + dx
            ny = y + dy
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            if visited[ny][nx]:
                continue

            pixel = pixels[nx, ny]
            matches = is_dark(pixel) if bg_type == "dark" else is_light(pixel)
            if matches:
                visited[ny][nx] = True
                queue.append((nx, ny, bg_type))

    return rgba


def crop_to_alpha_bounds(img):
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return img
    return img.crop(bbox)


def process_image(input_path, output_path):
    print(f"Processing: {input_path}")
    image = Image.open(input_path).convert("RGBA")
    cleaned = remove_edge_background(image)
    cropped = crop_to_alpha_bounds(cleaned)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    same_parent = input_path.parent == output_path.parent
    case_only_rename = (
        same_parent
        and input_path.name.lower() == output_path.name.lower()
        and input_path.name != output_path.name
    )

    if case_only_rename:
        temp_output = output_path.with_name(f"__processed__{output_path.name}")
        cropped.save(temp_output, "PNG")
        input_path.unlink()
        temp_output.replace(output_path)
    else:
        cropped.save(output_path, "PNG")

    print(f"  Saved: {output_path.name} {cropped.size}")


def list_target_files(folder_name, explicit_files):
    folder_path = ROOT_DIR / folder_name
    if explicit_files:
        return [folder_path / name for name in explicit_files]

    return sorted(
        path
        for path in folder_path.iterdir()
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description="Remove solid edge backgrounds from imported game assets.",
    )
    parser.add_argument(
        "--folder",
        action="append",
        choices=DEFAULT_FOLDERS,
        help="Target asset folder. Defaults to characters and enemies.",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        help="Optional list of file names inside the selected folder.",
    )
    parser.add_argument(
        "--rename-lowercase",
        action="store_true",
        help="Save processed output using lowercase file names.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    folders = tuple(args.folder) if args.folder else DEFAULT_FOLDERS

    for folder_name in folders:
        for input_path in list_target_files(folder_name, args.files):
            output_name = input_path.name.lower() if args.rename_lowercase else input_path.name
            output_path = input_path.with_name(output_name)
            process_image(input_path, output_path)


if __name__ == "__main__":
    main()
