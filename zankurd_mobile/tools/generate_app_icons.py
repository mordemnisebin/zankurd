from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
GREEN = (23, 122, 86)
RED = (212, 73, 66)
BROWN = (36, 28, 21)
CREAM = (251, 248, 242)


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf"),
        Path("C:/Windows/Fonts/calibrib.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def make_icon(size: int, maskable: bool = False) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    margin = int(size * (0.08 if maskable else 0.04))
    radius = int(size * 0.22)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=GREEN,
    )

    stripe_height = int(size * 0.2)
    draw.rounded_rectangle(
        [margin, size - margin - stripe_height, size - margin, size - margin],
        radius=radius,
        fill=BROWN,
    )
    draw.polygon(
        [
            (size - margin, margin),
            (size - margin, int(size * 0.42)),
            (int(size * 0.64), margin),
        ],
        fill=RED,
    )

    mark_font = font(int(size * 0.38))
    text = "ZK"
    bbox = draw.textbbox((0, 0), text, font=mark_font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    draw.text(
        ((size - text_w) / 2, (size - text_h) / 2 - int(size * 0.02)),
        text,
        fill=CREAM,
        font=mark_font,
    )
    return img


def save_android_icons() -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in sizes.items():
        out = ROOT / "android" / "app" / "src" / "main" / "res" / folder
        out.mkdir(parents=True, exist_ok=True)
        make_icon(size).save(out / "ic_launcher.png")


def save_web_icons() -> None:
    web = ROOT / "web"
    icons = web / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    make_icon(32).save(web / "favicon.png")
    make_icon(192).save(icons / "Icon-192.png")
    make_icon(512).save(icons / "Icon-512.png")
    make_icon(192, maskable=True).save(icons / "Icon-maskable-192.png")
    make_icon(512, maskable=True).save(icons / "Icon-maskable-512.png")


def save_windows_icon() -> None:
    out = ROOT / "windows" / "runner" / "resources"
    out.mkdir(parents=True, exist_ok=True)
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = [make_icon(size).convert("RGBA") for size in sizes]
    images[0].save(out / "app_icon.ico", sizes=[(size, size) for size in sizes])


def main() -> None:
    save_android_icons()
    save_web_icons()
    save_windows_icon()


if __name__ == "__main__":
    main()
