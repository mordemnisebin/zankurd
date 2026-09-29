#!/usr/bin/env python3
"""Uygulama simgesini, açılış görselini ve uygulama içi logoyu üretir.

Kaynak: L4 "soru balonu" işareti (turuncu konuşma balonu, içinde pahlı Z
oyuğu). Geometri aşağıda düz sayılarla yazılıdır (1024 kare, y aşağı);
tasarım klasöründeki `kimlik/logo/uret.py` aynı sayıları üretir. Görüntü
PIL ile 4 kat büyük çizilip küçültülür — ek kütüphane (cairo, chrome)
gerekmez. Çalıştır: `python3 tool/generate_app_icons.py` (zankurd_mobile/).

2026-09-30: logo değişti. Eski logo (kırmızı Z, güneş, dağ, kitap) yapay
zekâ üretimi bir resim gibi duruyordu ve 24 px'te okunmuyordu: dağ, ışın
ve alev birbirine karışıp bir leke çıkıyordu. Yeni işaret tek renk, tek
parça bir silüettir; 24 px'te bile balon + Z okunur. Eski dosyalar repo
dışında yedeklidir (`kimlik/logo/eski/`). Bu betik o resmi işleyen eski
araçların (`recolor_logo.py`, `make_logo_transparent.py`) yerini de aldı.

Kural (2026-07-27, değişmedi): **simge dosyalarında alfa olmaz** — App
Store alfa kanallı simgeyi reddeder; bu yüzden işaret düz bir zemine (gece
lacivert, `SahneTokens.night.bg`) bindirilir. Açılış görselleri ve
uygulama içi logo ise şeffaftır: açık ve karanlık zeminde de doğru durur.

Üretilenler: iOS AppIcon + LaunchImage, Android mipmap (+ uyarlanabilir
ön plan), bildirim silueti, splash_logo, web simgeleri, `assets/zankurd_icon.webp`
(işaret) ve `assets/zankurd.webp` (işaret + "ZanKurd" yatay kilidi).

Uygulama içinde yazı Flutter `Text` ile kalır (net, ölçeklenir, dile göre
değişebilir); kilit görseli yalnız dışarıya dönük kullanım içindir ve
yazısını Bricolage Grotesque ExtraBold'dan alır.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets/fonts/BricolageGrotesque-ExtraBold.ttf"

NIGHT = (10, 15, 46)      # #0A0F2E — SahneTokens.night.bg
AGIR = (255, 138, 61)     # #FF8A3D — işaret
CREAM = (246, 243, 236)   # #F6F3EC — kilit yazısı (gece zemini)

# ---- L4 geometrisi (1024 kare) -------------------------------------------
# Balon: 8 köşeli, sol altta kuyruk. Z: oyuk (evenodd). 2026-09-30: Z ~%12
# incelip küçüldü; balon kenarından boşluk arttı (24 px'te kapanmasın).
BUBBLE = [(242, 142), (782, 142), (912, 272), (912, 612), (782, 742),
          (252, 742), (112, 882), (112, 272)]
Z_HOLE = [(374, 319), (401, 292), (623, 292), (650, 319), (650, 371),
          (481, 513), (650, 513), (650, 565), (623, 592), (401, 592),
          (374, 565), (374, 513), (543, 371), (374, 371)]
MARK_BOX = (112, 142, 912, 882)  # işaretin sıkı sınırı
BODY_CENTER_Y = 442              # balon gövdesinin ortası (kuyruk hariç)

SS = 4  # süper örnekleme

# Simge içinde işaretin en uzun kenarının payı. iOS köşeleri yuvarlattığı
# için kenarda nefes payı bırakılır.
ICON_INSET = 0.16

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-50x50@1x.png": 50,
    "Icon-App-50x50@2x.png": 100, "Icon-App-57x57@1x.png": 57,
    "Icon-App-57x57@2x.png": 114, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-72x72@1x.png": 72,
    "Icon-App-72x72@2x.png": 144, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_ICONS = {
    "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
}

# Bildirim ikonu ölçüleri (dp -> px). Android bildirim küçük ikonunu
# **siluete** çevirir: rengi atar, yalnız alfayı kullanır (2026-07-27).
NOTIFICATION_ICONS = {
    "drawable-mdpi": 24, "drawable-hdpi": 36, "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72, "drawable-xxxhdpi": 96,
}

LAUNCH_IMAGES = {"LaunchImage.png": 180, "LaunchImage@2x.png": 360,
                 "LaunchImage@3x.png": 540}

WEB_ICONS = {
    "web/favicon.png": 32,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
}


def mark_mask(height: int) -> Image.Image:
    """İşaretin alfa maskesi (sıkı kesim), verilen yüksekliğe göre; balon
    dolu, Z oyuk."""
    x0, y0, x1, y1 = MARK_BOX
    k = height * SS / (y1 - y0)
    w, h = round((x1 - x0) * k), round((y1 - y0) * k)
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon([((x - x0) * k, (y - y0) * k) for x, y in BUBBLE], fill=255)
    draw.polygon([((x - x0) * k, (y - y0) * k) for x, y in Z_HOLE], fill=0)
    return mask.resize((round(w / SS), round(h / SS)), Image.LANCZOS)


def mark(height: int, color=AGIR) -> Image.Image:
    """Şeffaf zeminli renkli işaret (sıkı kesim)."""
    mask = mark_mask(height)
    out = Image.new("RGBA", mask.size, color + (255,))
    out.putalpha(mask)
    return out


def fit(image: Image.Image, box: int) -> Image.Image:
    """En uzun kenarı [box] olacak biçimde yeniden boyutlar."""
    scale = box / max(image.size)
    return image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.LANCZOS,
    )


def rendered(box: int, color=AGIR) -> Image.Image:
    """En uzun kenarı [box] piksel olan işaret (keskin: doğrudan o boyda çizilir)."""
    x0, y0, x1, y1 = MARK_BOX
    height = box if (y1 - y0) >= (x1 - x0) else round(box * (y1 - y0) / (x1 - x0))
    return mark(height, color)


def on_canvas(image: Image.Image, size: int, background) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), background)
    canvas.alpha_composite(
        image, ((size - image.width) // 2, (size - image.height) // 2)
    )
    return canvas


def icon(size: int) -> Image.Image:
    """Alfasız kare simge: gece zemini + işaret."""
    box = round(size * (1 - 2 * ICON_INSET))
    return on_canvas(rendered(box), size, NIGHT + (255,)).convert("RGB")


def lockup(height: int = 1024, ink=CREAM) -> Image.Image:
    """İşaret + "ZanKurd" yatay kilidi, şeffaf. Yazı işaretin gövdesiyle
    ortalanır; taban çizgisi Z'nin altındadır."""
    unit = height / (MARK_BOX[3] - MARK_BOX[1])           # 1 tasarım birimi
    m = mark(height)
    cap = 0.38 * height                                    # büyük harf boyu
    px = cap / 0.660                                       # em (cap = 660/1000)
    font = ImageFont.truetype(str(FONT), round(px * SS))
    track = -0.006 * px
    gap = 0.20 * height
    text_w = sum(font.getlength(c) / SS + track for c in "ZanKurd") - track
    body_c = (BODY_CENTER_Y - MARK_BOX[1]) * unit          # gövde ortası (y)
    baseline = body_c + cap / 2
    width = round(m.width + gap + text_w)
    layer = Image.new("L", (width * SS, height * SS), 0)
    draw = ImageDraw.Draw(layer)
    x = (m.width + gap) * SS
    for c in "ZanKurd":
        draw.text((x, baseline * SS), c, font=font, fill=255, anchor="ls")
        x += font.getlength(c) + track * SS
    text = Image.new("RGBA", (width, height), ink + (255,))
    text.putalpha(layer.resize((width, height), Image.LANCZOS))
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.alpha_composite(m, (0, 0))
    out.alpha_composite(text)
    return out.crop(out.getbbox())


def main() -> None:
    res = ROOT / "android/app/src/main/res"

    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in IOS_ICONS.items():
        icon(size).save(ios_dir / name)

    for folder, size in ANDROID_ICONS.items():
        icon(size).save(res / folder / "ic_launcher.png")

    # Android 8+ uyarlanabilir simge: ön plan (işaret) ile zemin ayrı
    # katmandır (`zk_icon_bg` = gece zemini), cihazın maskesi uygulanır.
    # 108 birimlik tuvalin yalnız ortadaki 72 birimi her maskede görünür;
    # işaret bunun içinde kalır. Android 13 tema simgesi (monochrome) aynı
    # ön planın alfasını kullanır: balon + Z oyuğu tek renkte de okunur.
    for folder, size in ANDROID_ICONS.items():
        canvas_size = round(size / 48 * 108)
        box = round(canvas_size * 72 / 108 * 0.84)
        on_canvas(rendered(box), canvas_size, (0, 0, 0, 0)).save(
            res / folder / "ic_launcher_fg.png"
        )

    # Bildirim silueti: aynı işaret, düz beyaz.
    for folder, size in NOTIFICATION_ICONS.items():
        target = res / folder
        target.mkdir(parents=True, exist_ok=True)
        box = round(size * 0.9)
        on_canvas(rendered(box, (255, 255, 255)), size, (0, 0, 0, 0)).save(
            target / "ic_stat_zankurd.png"
        )

    # Açılış görselleri şeffaf kalır (yalnız işaret).
    launch_dir = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, size in LAUNCH_IMAGES.items():
        rendered(size).save(launch_dir / name)
    rendered(512).save(res / "drawable/splash_logo.png")

    for relative, size in WEB_ICONS.items():
        icon(size).save(ROOT / relative)

    # Uygulama içi logo: işaret (1024 yüksek) ve yatay kilit. Bilerek WebP
    # kayıpsız: keskin kenarlı düz renk, kayıplı sıkıştırmada halelenir.
    rendered(1024).save(ROOT / "assets/zankurd_icon.webp", lossless=True)
    lockup(512).save(ROOT / "assets/zankurd.webp", lossless=True)

    print("simgeler, açılış görselleri ve uygulama içi logo üretildi")


if __name__ == "__main__":
    main()
