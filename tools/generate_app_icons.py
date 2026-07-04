from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SKY_PATH = ROOT / "assets" / "images" / "sky.png"
DRAGON_ATLAS_PATH = ROOT / "assets" / "images" / "dragon_atlas.png"

BASE_SIZE = 1024
DRAGON_FRAME = 0
DRAGON_CELL_WIDTH = 256
DRAGON_VISIBLE_BOX = (15, 12, 15 + 226, 12 + 167)


ANDROID_ICON_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _resample() -> Image.Resampling:
    return Image.Resampling.LANCZOS


def _square_sky_background(size: int) -> Image.Image:
    sky = Image.open(SKY_PATH).convert("RGB")
    crop_size = min(sky.width, sky.height)
    left = (sky.width - crop_size) // 2
    top = (sky.height - crop_size) // 2
    return sky.crop((left, top, left + crop_size, top + crop_size)).resize(
        (size, size),
        _resample(),
    )


def _dragon_sprite(size: int, width_fraction: float, height_fraction: float) -> Image.Image:
    atlas = Image.open(DRAGON_ATLAS_PATH).convert("RGBA")
    left, top, right, bottom = DRAGON_VISIBLE_BOX
    frame_left = DRAGON_FRAME * DRAGON_CELL_WIDTH + left
    dragon = atlas.crop((frame_left, top, frame_left + (right - left), bottom))

    bbox = dragon.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Dragon sprite has no visible pixels")
    dragon = dragon.crop(bbox)

    max_width = int(size * width_fraction)
    max_height = int(size * height_fraction)
    scale = min(max_width / dragon.width, max_height / dragon.height)
    return dragon.resize(
        (round(dragon.width * scale), round(dragon.height * scale)),
        _resample(),
    )


def make_icon(size: int, *, mask_safe: bool = False) -> Image.Image:
    background = _square_sky_background(size).convert("RGBA")
    dragon = _dragon_sprite(
        size,
        width_fraction=0.64 if mask_safe else 0.74,
        height_fraction=0.62 if mask_safe else 0.72,
    )
    alpha = dragon.getchannel("A")

    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(max(1, size // 128))).point(
        lambda value: int(value * 0.38),
    )
    glow = Image.new("RGBA", dragon.size, (255, 255, 255, 0))
    glow.putalpha(glow_alpha)

    shadow_alpha = alpha.filter(ImageFilter.GaussianBlur(max(4, size // 32))).point(
        lambda value: int(value * 0.42),
    )
    shadow = Image.new("RGBA", dragon.size, (18, 70, 95, 0))
    shadow.putalpha(shadow_alpha)

    x = (size - dragon.width) // 2
    y = (size - dragon.height) // 2
    layer = Image.new("RGBA", background.size, (0, 0, 0, 0))
    layer.alpha_composite(shadow, (x + size // 28, y + size // 28))
    layer.alpha_composite(glow, (x, y))
    layer.alpha_composite(dragon, (x, y))

    return Image.alpha_composite(background, layer).convert("RGB")


def _save_png(path: Path, source: Image.Image, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), _resample()).save(path)


def _generate_web(base: Image.Image, maskable: Image.Image) -> None:
    web_dir = ROOT / "web"
    icons_dir = web_dir / "icons"
    _save_png(web_dir / "favicon.png", base, 16)
    _save_png(icons_dir / "Icon-192.png", base, 192)
    _save_png(icons_dir / "Icon-512.png", base, 512)
    _save_png(icons_dir / "Icon-maskable-192.png", maskable, 192)
    _save_png(icons_dir / "Icon-maskable-512.png", maskable, 512)


def _generate_android(base: Image.Image) -> None:
    res_dir = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, size in ANDROID_ICON_SIZES.items():
        _save_png(res_dir / density / "ic_launcher.png", base, size)


def _ios_icon_size(entry: dict[str, str]) -> int:
    point_size = float(entry["size"].split("x", maxsplit=1)[0])
    scale = int(entry["scale"].rstrip("x"))
    return round(point_size * scale)


def _generate_ios(base: Image.Image) -> None:
    app_icon_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents_path = app_icon_dir / "Contents.json"
    contents = json.loads(contents_path.read_text(encoding="utf-8"))

    generated: set[str] = set()
    for image in contents["images"]:
        filename = image.get("filename")
        if not filename or filename in generated:
            continue
        generated.add(filename)
        _save_png(app_icon_dir / filename, base, _ios_icon_size(image))


def _generate_windows(base: Image.Image) -> None:
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    base.save(ico_path, sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def main() -> None:
    base = make_icon(BASE_SIZE)
    maskable = make_icon(BASE_SIZE, mask_safe=True)

    _generate_web(base, maskable)
    _generate_android(base)
    _generate_ios(base)
    _generate_windows(base)

    print("Generated app icons from game sky and dragon atlas.")


if __name__ == "__main__":
    main()
