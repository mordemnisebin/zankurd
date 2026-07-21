"""Eski çok-renkli ZanKurd logosunu (Z + güneş + dağ + kitap + "ZANKURD"
wordmark) aynı şekliyle koruyup, güncel uygulama paletine (AppTheme)
uyarlayarak yeniden boyar.

Teknik: anti-aliasing (binlerce ara ton) nedeniyle basit tam-renk
değiştirme işe yaramaz. Bunun yerine her piksel, orijinaldeki 5 çapa
renkten (kırmızı/yeşil/altın/lacivert/beyaz) hangisine en yakınsa o
gruba atanır; yeni renk = yeni_çapa + (piksel - eski_çapa) — bu, kenar
piksellerindeki gölgelendirme/blend'i olduğu gibi korur.

Renk eşlemesi (AppTheme sabitlerinden, lib/src/theme/app_theme.dart):
  kırmızı (Kürt bayrağı) -> brandGreenDeep #E06E12 (koyu turuncu, gradyan ucu)
  yeşil   (Kürt bayrağı) -> brandGreen     #F5931E (turuncu, gradyan başı)
  altın/sarı              -> secondaryAccent #E7B53C (aynı sıcak-altın ailesi)
  lacivert (dağ+"ZAN")    -> lightTextPrimary #1A1A24 (uygulamanın başlık rengi)
  beyaz zemin             -> değişmez
"""
from PIL import Image

SRC = "tool/old_zankurd_logo.webp"
DST = "assets/zankurd.webp"

ANCHORS = [
    # (eski_rgb, yeni_rgb)
    ((242, 28, 41), (224, 110, 18)),   # kırmızı -> brandGreenDeep
    ((2, 100, 49), (245, 147, 30)),    # yeşil -> brandGreen
    ((254, 189, 17), (231, 181, 60)),  # altın -> secondaryAccent
    ((29, 39, 47), (26, 26, 36)),      # lacivert -> lightTextPrimary
    ((255, 255, 255), (255, 255, 255)),  # beyaz -> değişmez
]


def main():
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    px = img.load()

    # 256^3 aralığı için önbellek: aynı (r,g,b) çok kez tekrar edeceğinden
    # (düz renkli logo) her pikseli yeniden hesaplamak yerine önbellekle.
    cache = {}

    def remap(r, g, b):
        # Sert en-yakın-çapa ataması, gölgelendirme/blend geçiş
        # bölgelerinde (ör. lacivert dağın yeşile değdiği kenar) görünür
        # bir dikiş bırakıyordu. Bunun yerine ters-mesafe-karesi ağırlıklı
        # yumuşak karışım: her çapanın ofseti, o çapaya yakınlığıyla
        # orantılı ağırlıkla karışıyor — geçiş bölgeleri sertçe tek bir
        # tarafa düşmek yerine iki hedef arasında yumuşak kayıyor.
        key = (r, g, b)
        cached = cache.get(key)
        if cached is not None:
            return cached

        weights = []
        total = 0.0
        exact = None
        for i, (old, _new) in enumerate(ANCHORS):
            d2 = (r - old[0]) ** 2 + (g - old[1]) ** 2 + (b - old[2]) ** 2
            if d2 == 0:
                exact = i
                break
            wgt = 1.0 / (d2 ** 1.5)
            weights.append(wgt)
            total += wgt

        if exact is not None:
            weights = [1.0 if i == exact else 0.0 for i in range(len(ANCHORS))]
            total = 1.0

        dr = dg = db = 0.0
        for (old, new), wgt in zip(ANCHORS, weights):
            f = wgt / total
            dr += f * (new[0] - old[0])
            dg += f * (new[1] - old[1])
            db += f * (new[2] - old[2])

        out = (
            max(0, min(255, round(r + dr))),
            max(0, min(255, round(g + dg))),
            max(0, min(255, round(b + db))),
        )
        cache[key] = out
        return out

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            nr, ng, nb = remap(r, g, b)
            px[x, y] = (nr, ng, nb, a)

    img.save(DST, "WEBP", quality=95)
    print("Yazıldı:", DST, "| önbellek boyutu:", len(cache))


if __name__ == "__main__":
    main()
