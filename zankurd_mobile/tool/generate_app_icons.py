#!/usr/bin/env python3
"""Uygulama simgesini ve açılış görselini gerçek logodan üretir.

2026-07-27: uygulama simgesi lacivert bir kare üzerinde kırmızı yuvarlak
ve beyaz "ZK" harfleriydi — Flutter şablonundan kalma bir yer tutucu.
Ürünün logosuyla hiçbir ilgisi yoktu. Kullanıcının telefonunda uygulamayı
**açmadan** gördüğü tek şey budur.

Kaynak: `android/.../splash_logo.png` içindeki çok renkli logo (kırmızı Z,
yeşil dağ tabanı, sarı güneş, kitap). Beyaz zemin şeffaflaştırılır ve
amblem, "ZANKURD" yazısından ayrılır — küçük boyutlarda yazı okunmaz,
simgede yalnız amblem durur.

Açılış görseli de aynı şeffaf amblemden üretilir. Eskisi beyaz zemini
gömülü bir bitmap'ti: karanlık temada koyu arka planın ortasında beyaz
bir kare olarak çıkıyordu.

Simge dosyalarında alfa **olmaz** — App Store alfa kanallı simgeyi
reddeder; bu yüzden amblem düz bir zemine bindirilir.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "android/app/src/main/res/drawable/splash_logo.png"

# Simge zemini: logonun tasarlandığı beyaz. Amblemin sarı güneş ışınları
# krem zeminde soluyor; beyaz en yüksek ayrımı verir.
ICON_BG = (255, 255, 255, 255)

# Amblemin simge içindeki oranı. iOS köşeleri yuvarlattığı için kenarda
# nefes payı bırakılır.
ICON_INSET = 0.16

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_ICONS = {
    "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
}

LAUNCH_IMAGES = {"LaunchImage.png": 180, "LaunchImage@2x.png": 360,
                 "LaunchImage@3x.png": 540}

# Web sürümünün sekme ve yükleme simgeleri de aynı yer tutucudandı.
WEB_ICONS = {
    "web/favicon.png": 32,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
}


def transparent_logo() -> Image.Image:
    """Beyaz zemini şeffaflaştırılmış tam logo (amblem + yazı)."""
    src = Image.open(SOURCE).convert("RGBA")
    out = Image.new("RGBA", src.size)
    sp, op = src.load(), out.load()
    width, height = src.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = sp[x, y]
            level = min(r, g, b)
            if level >= 250:
                op[x, y] = (r, g, b, 0)
            elif level >= 200:
                # Kenar yumuşatması: beyaza yaklaştıkça saydamlaşır. Sert
                # eşik kullanılsa amblemin kenarı testere dişi olurdu.
                op[x, y] = (r, g, b, int((250 - level) / 50 * 255))
            else:
                op[x, y] = (r, g, b, a)
    return out


def emblem_only(logo: Image.Image) -> Image.Image:
    """Yazısız amblem. Yazı ile amblem arasındaki boş satır bandı sınırdır."""
    width, height = logo.size
    px = logo.load()
    filled = [
        sum(1 for x in range(0, width, 2) if px[x, y][3] > 8)
        for y in range(height)
    ]
    top = next(i for i, c in enumerate(filled) if c > 2)
    gap = next(
        y for y in range(top + height // 4, height) if filled[y] <= 1
    )
    return logo.crop((0, top, width, gap)).crop(
        logo.crop((0, top, width, gap)).getbbox()
    )


def square(image: Image.Image, size: int, background) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    inner = int(size * (1 - 2 * ICON_INSET))
    scale = min(inner / image.width, inner / image.height)
    resized = image.resize(
        (max(1, int(image.width * scale)), max(1, int(image.height * scale))),
        Image.LANCZOS,
    )
    canvas.alpha_composite(
        resized,
        ((size - resized.width) // 2, (size - resized.height) // 2),
    )
    return canvas


def main() -> None:
    logo = transparent_logo()
    emblem = emblem_only(logo)

    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in IOS_ICONS.items():
        # Alfa kanalı yok: App Store reddeder.
        square(emblem, size, ICON_BG).convert("RGB").save(ios_dir / name)

    for folder, size in ANDROID_ICONS.items():
        target = ROOT / "android/app/src/main/res" / folder / "ic_launcher.png"
        square(emblem, size, ICON_BG).convert("RGB").save(target)

    # Açılış görseli şeffaf kalır: açık ve karanlık zeminde de doğru durur.
    launch_dir = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, size in LAUNCH_IMAGES.items():
        scale = size / max(logo.width, logo.height)
        logo.resize(
            (int(logo.width * scale), int(logo.height * scale)), Image.LANCZOS
        ).save(launch_dir / name)

    android_splash = ROOT / "android/app/src/main/res/drawable/splash_logo.png"
    scale = 512 / max(logo.width, logo.height)
    logo.resize(
        (int(logo.width * scale), int(logo.height * scale)), Image.LANCZOS
    ).save(android_splash)

    for relative, size in WEB_ICONS.items():
        # Maskable simgeler kırpılabilir: içeriden daha fazla pay bırakılır.
        square(emblem, size, ICON_BG).convert("RGB").save(ROOT / relative)

    print("simgeler ve açılış görselleri üretildi")


if __name__ == "__main__":
    main()
