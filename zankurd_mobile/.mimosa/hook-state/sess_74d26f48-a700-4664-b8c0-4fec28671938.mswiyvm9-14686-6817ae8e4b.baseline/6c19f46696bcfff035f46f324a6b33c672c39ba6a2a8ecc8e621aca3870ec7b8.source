"""zankurd.webp'nin opak beyaz arka planını saydama çevirir.

Basit "beyaza yakın pikselleri sil" yaklaşımı, logonun İÇİNDEKİ açık
tonları (dağın kar tepeleri, alevin parlak ucu) da silebilir. Bunun
yerine kenarlardan başlayan bir BFS/flood-fill ile yalnızca resmin
KENARLARINA bağlı beyaz bölge (= gerçek arka plan) saydamlaştırılır;
logonun içindeki izole açık tonlar dokunulmadan kalır.
"""
from collections import deque
from pathlib import Path

from PIL import Image

SRC = "assets/zankurd.webp"
DST = "assets/zankurd.webp"
WHITE_THRESHOLD = 235  # bu değerin üstündeki R,G,B hepsi -> "beyaza yakın" aday


def main():
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    px = img.load()

    def is_whiteish(r, g, b):
        return r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD

    visited = bytearray(w * h)
    q = deque()

    def maybe_enqueue(x, y):
        idx = y * w + x
        if visited[idx]:
            return
        r, g, b, _a = px[x, y]
        if not is_whiteish(r, g, b):
            visited[idx] = 1  # işaretle ama arka plan değil
            return
        visited[idx] = 2  # arka plan adayı, kuyruğa eklendi
        q.append((x, y))

    for x in range(w):
        maybe_enqueue(x, 0)
        maybe_enqueue(x, h - 1)
    for y in range(h):
        maybe_enqueue(0, y)
        maybe_enqueue(w - 1, y)

    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx]:
                maybe_enqueue(nx, ny)

    bg_count = 0
    for y in range(h):
        row_base = y * w
        for x in range(w):
            if visited[row_base + x] == 2:
                r, g, b, _a = px[x, y]
                # Beyazdan saydama yumuşak geçiş: eşiğe ne kadar yakınsa
                # o kadar saydam (anti-aliased kenarlarda sert kesim olmasın).
                # brightness == 253+ (tam beyaz) -> alpha 0 (tam saydam)
                # brightness == WHITE_THRESHOLD (eşik) -> alpha 255 (tam opak)
                brightness = min(r, g, b)
                span = 253 - WHITE_THRESHOLD
                # frac=0 tam beyaz (brightness>=253) -> alpha 0 (saydam)
                # frac=1 eşiğe yakın (brightness==WHITE_THRESHOLD) -> alpha 255 (opak)
                frac = max(0.0, min(1.0, (253 - brightness) / span))  # 0..1
                alpha = round(frac * 255)
                px[x, y] = (r, g, b, alpha)
                bg_count += 1

    img.save(DST, "WEBP", lossless=True)
    print("Saydamlaştırılan piksel:", bg_count, "/", w * h)


if __name__ == "__main__":
    main()
