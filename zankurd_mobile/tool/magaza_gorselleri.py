#!/usr/bin/env python3
"""Mağaza görsellerini üretir: ekran görüntüleri, Play öne çıkan görsel, Play simgesi.

Çalıştır (zankurd_mobile/ içinde): `python3 tool/magaza_gorselleri.py`
Pillow gerekir (`pip install pillow` ya da bir venv).

Girdi: `docs/screenshots/store/tr/raw/` altındaki ham simülatör görüntüleri
(iPhone 17 Pro Max, 1320x2868, Türkçe arayüz, Şahnê tasarımı; tarif
`docs/store_listing.md` -> "Mağaza ekran görüntüleri"). Bu klasör sürüm
denetiminde tutulmaz (`docs/screenshots/` .gitignore'da): üretilmiş görsel
kaynak gibi davranmasın diye, kaynak bu betiktir.

Çıktı (`docs/screenshots/store/`):
  tr/01_...png ... tr/08_...png   1320x2868, App Store 6,9" ve Play telefon
  play_feature_graphic.png        1024x500
  play_icon_512.png               512x512, 32 bit PNG

Renkler uydurulmadı: `lib/src/theme/sahne.dart` içindeki gece belirteçleri
(`SahneTokens.night`) okunur. Logo ve simge `tool/generate_app_icons.py`
içindeki aynı çizim kodundan gelir (yeniden çizilmez, içe aktarılır), böylece
mağaza simgesi uygulamanın içindeki simgeyle birebir aynıdır.

Başlıklar yalnız ekranın GERÇEKTEN gösterdiğini söyler; yeni bir ekran
eklenirse başlığı da görüntüye göre yaz (en çok 32 karakter).
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_app_icons as gai  # noqa: E402  (aynı logo/simge çizimi)

RAW = ROOT / "docs/screenshots/store/tr/raw"
OUT = ROOT / "docs/screenshots/store"
FONTS = ROOT / "assets/fonts"
HEADLINE_FONT = FONTS / "BricolageGrotesque-ExtraBold.ttf"
BODY_FONT = FONTS / "Onest-SemiBold.ttf"
SF_FONT = Path("/System/Library/Fonts/SFNS.ttf")  # yalnız durum çubuğu saati

W, H = 1320, 2868  # App Store 6,9" ve Play için tam boyut


def night_tokens() -> dict:
    """`SahneTokens.night` içindeki `ad: Color(0xAARRGGBB)` satırlarını okur."""
    src = (ROOT / "lib/src/theme/sahne.dart").read_text(encoding="utf-8")
    block = src.split("static const night", 1)[1].split("static const day", 1)[0]
    out = {}
    for name, argb in re.findall(r"(\w+): Color\(0x([0-9A-Fa-f]{8})\)", block):
        out[name] = tuple(int(argb[i:i + 2], 16) for i in (2, 4, 6))
    return out


T = night_tokens()
BG, NAV, S1, S3 = T["bg"], T["nav"], T["s1"], T["s3"]
TX, TX2, ACT, RACE = T["tx"], T["tx2"], T["act"], T["race"]

# (çıktı adı, ham görüntü, başlık). Sıra: önce yarışma, sonra öğrenme.
SHOTS = [
    ("01_yaris", "yaris.png", "Arkadaşına meydan oku"),
    ("02_fotografli_soru", "quiz_photo.png", "Kürt kültürünü sınayan sorular"),
    ("03_duello_puan", "quiz_4opt.png", "Canlı puanla düello"),
    ("04_sonuc", "res2.png", "Sonucunu paylaş"),
    ("05_oda", "room1.png", "Oda kur, kodla davet et"),
    ("06_ana_ekran", "home3.png", "Günlük hedef, seri ve seviye"),
    ("07_ders_yolu", "learn.png", "Alfabeden başla"),
    ("08_sozluk", "dict1.png", "1.119 kelime ve ifade"),
]


def vgradient(size, top, bottom) -> Image.Image:
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        k = y / max(1, h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * k) for a, b in zip(top, bottom)))
    return col.resize((w, h))


def glow(canvas: Image.Image, center, radius, color, alpha) -> None:
    """Yumuşak, tek renkli ışık lekesi (zemin derinliği için)."""
    layer = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(layer).ellipse(
        [center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius],
        fill=round(255 * alpha),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.55))
    canvas.paste(Image.new("RGB", canvas.size, color), (0, 0), layer)


def background(size) -> Image.Image:
    """Şahnê gecesi: lacivert zemin, sağ üstte Agir, sol altta Yarış ışığı."""
    w, h = size
    canvas = vgradient(size, BG, NAV)
    glow(canvas, (round(w * 0.88), round(h * 0.10)), round(w * 0.55), ACT, 0.17)
    glow(canvas, (round(w * 0.05), round(h * 0.92)), round(w * 0.60), RACE, 0.16)
    return canvas


def rounded_mask(size, radius, ss=3) -> Image.Image:
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def fix_status_clock(shot: Image.Image, text="9:41") -> Image.Image:
    """Durum çubuğu saatini sabitler (9:41). Ham görüntüler farklı anlarda alındı
    (12:44, 13:03...); saat uyumsuzluğu mağaza setini amatör gösterir. Saatin
    çevresindeki zemin yatay doğrusal geçişle doldurulur, yeni saat SF ile çizilir."""
    shot = shot.convert("RGB")
    x0, x1, y0, y1 = 120, 380, 50, 150  # saatin bulunduğu bölge (1320x2868)
    # Eski saatin sıkı kutusu: bölgedeki parlak pikseller.
    px = shot.load()
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0 + 20, x1 - 20):
            r, g, b = px[x, y]
            if r + g + b > 560:
                xs.append(x)
                ys.append(y)
    if not xs:
        return shot
    bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
    cx = (bx0 + bx1) / 2
    digit_h = by1 - by0 + 1
    # Bölgeyi sol/sağ kenar pikselleri arasında doğrusal geçişle doldur.
    for y in range(y0, y1):
        left, right = px[x0 - 2, y], px[x1 + 2, y]
        for x in range(x0, x1):
            k = (x - x0) / (x1 - x0)
            px[x, y] = tuple(round(a + (b - a) * k) for a, b in zip(left, right))
    path = SF_FONT if SF_FONT.exists() else BODY_FONT
    size = 60
    while True:
        font = ImageFont.truetype(str(path), size)
        if path == SF_FONT:
            try:
                font.set_variation_by_name("Semibold")
            except Exception:  # noqa: BLE001 - sürüm farkı; varsayılan kalınlık
                pass
        box = ImageDraw.Draw(shot).textbbox((0, 0), "9", font=font)
        if box[3] - box[1] >= digit_h or size > 120:
            break
        size += 1
    d = ImageDraw.Draw(shot)
    tb = d.textbbox((0, 0), text, font=font, anchor="ls")
    tw = tb[2] - tb[0]
    d.text((cx - tw / 2 - tb[0], by1), text, font=font, fill=(255, 255, 255), anchor="ls")
    return shot


def fit_headline(text: str, max_w: int, max_lines=2):
    """Başlığı en büyük puntoyla en çok [max_lines] satıra sığdırır."""
    for size in range(132, 70, -2):
        font = ImageFont.truetype(str(HEADLINE_FONT), size)
        words, lines, cur = text.split(), [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            if font.getlength(trial) <= max_w:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
        if len(lines) <= max_lines and all(font.getlength(l) <= max_w for l in lines):
            return font, lines
    raise ValueError(f"başlık sığmıyor: {text}")


def device_frame(shot: Image.Image, width: int) -> Image.Image:
    """Ekran görüntüsünü yuvarlak köşeli, ince çerçeveli ve gölgeli bir aygıt
    gibi hazırlar; şeffaf RGBA döner."""
    scale = width / shot.width
    height = round(shot.height * scale)
    scr = shot.resize((width, height), Image.LANCZOS).convert("RGBA")
    radius = round(width * 0.135)
    pad = 10  # çerçeve kalınlığı
    out_w, out_h = width + 2 * pad, height + 2 * pad
    body = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    # çerçeve: Şahnê s3 tonu, üstüne ince açık kenar
    frame = Image.new("RGBA", (out_w, out_h), S3 + (255,))
    body.paste(frame, (0, 0), rounded_mask((out_w, out_h), radius + pad))
    iw, ih = out_w - 2 * (pad - 4), out_h - 2 * (pad - 4)
    inner = Image.new("RGBA", (iw, ih), (0, 0, 0, 255))
    body.paste(inner, (pad - 4, pad - 4), rounded_mask((iw, ih), radius + 4))
    body.paste(scr, (pad, pad), rounded_mask((width, height), radius))
    return body


def drop_shadow(canvas: Image.Image, device: Image.Image, pos, blur=60, dy=40, alpha=150):
    shadow = Image.new("L", canvas.size, 0)
    shadow.paste(device.split()[3].point(lambda a: a * alpha // 255), (pos[0], pos[1] + dy))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", canvas.size, (2, 4, 18)), (0, 0), shadow)


def compose_screenshot(raw_name: str, headline: str) -> Image.Image:
    raw = Image.open(RAW / raw_name)
    assert raw.size == (W, H), f"{raw_name}: {raw.size} (1320x2868 bekleniyor)"
    shot = fix_status_clock(raw)
    canvas = background((W, H))
    d = ImageDraw.Draw(canvas)
    font, lines = fit_headline(headline, 1100)
    line_h = round(font.size * 1.08)
    top = 130
    # Agir şeridi: başlığın üstünde küçük vurgu
    d.rounded_rectangle([110, top, 110 + 96, top + 14], 7, fill=ACT)
    y = top + 56
    for line in lines:
        d.text((110, y), line, font=font, fill=TX, anchor="la")
        y += line_h
    # Aygıt: başlık alanının altında, alta kadar uzar (kenar boşlukları eşit).
    dev_w = 1010
    device = device_frame(shot, dev_w)
    dx = (W - device.width) // 2
    dy = max(y + 40, 560)
    # Alt kenarı taşırmak yerine sığdır: yüksekliği tuvale uydur.
    avail = H - dy - 90
    if device.height > avail:
        dev_w = round((avail - 20) * shot.width / shot.height)
        device = device_frame(shot, dev_w)
        dx = (W - device.width) // 2
    drop_shadow(canvas, device, (dx, dy))
    canvas.paste(device, (dx, dy), device)
    return canvas


def feature_graphic() -> Image.Image:
    """Play öne çıkan görsel, 1024x500: logo + ad + slogan; sağda iki ekran."""
    fw, fh = 1024, 500
    canvas = background((fw, fh))
    # Sağ: iki aygıt, alt kenardan taşar (kesik görünmesi doğal).
    for name, left, top, width in (("quiz_photo.png", 790, 60, 215), ("yaris.png", 600, 150, 215)):
        shot = fix_status_clock(Image.open(RAW / name))
        device = device_frame(shot, width)
        drop_shadow(canvas, device, (left, top), blur=24, dy=14, alpha=170)
        canvas.paste(device, (left, top), device)
    # Sol: kilit (işaret + ZanKurd) ve slogan.
    lock = gai.lockup(118)
    canvas.paste(lock, (60, 150), lock)
    d = ImageDraw.Draw(canvas)
    tag = ImageFont.truetype(str(BODY_FONT), 36)
    d.text((62, 150 + lock.height + 34), "Kürtçe bilgi yarışması", font=tag, fill=TX2, anchor="la")
    d.rounded_rectangle([62, 150 + lock.height + 100, 62 + 96, 150 + lock.height + 112], 6, fill=ACT)
    return canvas


def play_icon() -> Image.Image:
    """Play yüksek çözünürlüklü simge: uygulama simgesiyle aynı çizim, 32 bit PNG."""
    return gai.icon(512).convert("RGBA")


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    size_mb = path.stat().st_size / 1e6
    assert size_mb < 8, f"{path.name} {size_mb:.1f} MB (8 MB sınırı)"
    print(f"{path.relative_to(ROOT)}  {img.width}x{img.height}  {size_mb:.2f} MB")


def main() -> None:
    missing = [raw for _, raw, _ in SHOTS if not (RAW / raw).exists()]
    if missing:
        sys.exit(f"ham görüntü yok ({RAW}): {', '.join(missing)}")
    for out_name, raw, headline in SHOTS:
        assert len(headline) <= 32, f"başlık {len(headline)} karakter: {headline}"
        save(compose_screenshot(raw, headline).convert("RGB"), OUT / "tr" / f"{out_name}.png")
    save(feature_graphic(), OUT / "play_feature_graphic.png")
    save(play_icon(), OUT / "play_icon_512.png")


if __name__ == "__main__":
    main()
