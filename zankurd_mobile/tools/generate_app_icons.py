"""ZanKurd app icon generator — dark navy + coral gradient brand.

Matches the in-app design language:
  bg gradient : #1A1A2E -> #16213E (deep navy)
  accent      : #E94560 -> #BD1E3B (coral gradient, used for the ZK badge)
  gold        : #FFB800 (spark accent)
"""

import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]

NAVY_TOP = (26, 26, 46)
NAVY_BOTTOM = (22, 33, 62)
CORAL_TOP = (233, 69, 96)
CORAL_BOTTOM = (189, 30, 59)
GOLD = (255, 184, 0)
WHITE = (255, 255, 255)


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


def _vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    grad = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        ImageDraw.Draw(grad).line([(0, y), (size, y)], fill=color + (255,))
    return grad


def _rounded_mask(size: int, radius: int, margin: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=radius,
        fill=255,
    )
    return mask


def make_icon(size: int, maskable: bool = False) -> Image.Image:
    # Render at 4x for crisp edges on small sizes, then downscale.
    scale = 4
    s = size * scale
    margin = int(s * (0.10 if maskable else 0.02))
    radius = int(s * 0.24)

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # Navy gradient rounded square base
    base = _vertical_gradient(s, NAVY_TOP, NAVY_BOTTOM)
    img.paste(base, (0, 0), _rounded_mask(s, radius, margin))
    draw = ImageDraw.Draw(img)

    # Decorative circles (echo of the in-app hero cards)
    deco = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    deco_draw = ImageDraw.Draw(deco)
    deco_draw.ellipse(
        [int(s * 0.62), int(-s * 0.18), int(s * 1.12), int(s * 0.32)],
        fill=CORAL_TOP + (38,),
    )
    deco_draw.ellipse(
        [int(-s * 0.16), int(s * 0.66), int(s * 0.34), int(s * 1.16)],
        fill=(124, 58, 237, 34),  # violet
    )
    img = Image.composite(
        Image.alpha_composite(img, deco), img, _rounded_mask(s, radius, margin)
    )
    draw = ImageDraw.Draw(img)

    # Coral gradient badge in the middle
    badge_margin = int(s * 0.235)
    badge_radius = int(s * 0.13)
    badge = _vertical_gradient(s, CORAL_TOP, CORAL_BOTTOM)
    img.paste(badge, (0, 0), _rounded_mask(s, badge_radius, badge_margin))
    draw = ImageDraw.Draw(img)

    # ZK monogram
    mark_font = font(int(s * 0.30))
    text = "ZK"
    bbox = draw.textbbox((0, 0), text, font=mark_font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    draw.text(
        ((s - text_w) / 2 - bbox[0], (s - text_h) / 2 - bbox[1]),
        text,
        fill=WHITE,
        font=mark_font,
    )

    # Gold spark at the badge corner
    spark_r = int(s * 0.045)
    spark_cx = s - badge_margin
    spark_cy = badge_margin
    draw.ellipse(
        [
            spark_cx - spark_r,
            spark_cy - spark_r,
            spark_cx + spark_r,
            spark_cy + spark_r,
        ],
        fill=GOLD,
    )

    return img.resize((size, size), Image.LANCZOS)


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


def save_ios_icons() -> None:
    """Regenerate every PNG already present in the AppIcon set.

    Sizes are parsed from filenames like Icon-App-20x20@2x.png -> 40px.
    iOS icons must be opaque (no alpha), so they get a navy background.
    """
    appiconset = (
        ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    )
    if not appiconset.exists():
        return
    pattern = re.compile(r"Icon-App-([\d.]+)x[\d.]+@(\d)x\.png")
    for png in appiconset.glob("Icon-App-*.png"):
        match = pattern.match(png.name)
        if not match:
            continue
        size = int(float(match.group(1)) * int(match.group(2)))
        icon = make_icon(size, maskable=True)
        opaque = Image.new("RGB", icon.size, NAVY_BOTTOM)
        opaque.paste(icon, (0, 0), icon)
        opaque.save(png)


def main() -> None:
    save_android_icons()
    save_web_icons()
    save_windows_icon()
    save_ios_icons()
    print("All icons regenerated.")


if __name__ == "__main__":
    main()
