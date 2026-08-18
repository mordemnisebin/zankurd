# -*- coding: utf-8 -*-
"""Gözle seçilmiş Commons fotoğraflarını indirir, ölçekler ve künyeyi yazar.

Seçim otomatik yapılmadı. `harvest_commons_candidates.py` her kavram için
lisansı uygun adayları toplar, adaylar başlık ve görüntüyle tek tek
denetlenir, kabul edilenler burada sabitlenir. Denetimde elenen örnekler
neden gerekli olduğunu gösteriyor: "erbane" kategorisinin ilk sırasında
Bella Coola yerlilerinin fotoğrafı, "Göbekli Tepe" sırasında İngilizce bir
bilgi görseli, "bilûr" sırasında Tunus yapımı bir ney'in müze vitrini vardı.

Lisans politikası (uygulama sahibinin kararı, 2026-07-26): kamu malı, CC0
ve CC BY. CC BY-SA dışarıda — share-alike, yayımlanan üründe türev
yükümlülüğü doğurur. CC BY atıf istediği için her dosyanın fotoğrafçısı ve
kaynağı `assets/data/image_credits.json` içine yazılır; uygulamada
"Görsel kaynakları" ekranı bunu gösterir. Atıfsız kullanım ihlaldir.
"""

import json
import os
import subprocess
import sys
import time
import urllib.request

OUT_DIR = 'assets/question_images'
CREDITS = 'assets/data/image_credits.json'
MANIFEST = '/tmp/zk_commons/manifest.json'
UA = 'ZanKurd/1.0 (educational quiz app; contact nisebinbawer47@gmail.com)'

# slug: aday dizini (manifest sırası)
SELECTED = {
    'ava_zape': 1,
    'cilubergen_kurdi': 1,
    'ciyaye_agiri': 3,
    'ciyayen_munzur': 0,
    'ciyayen_zagros': 1,
    'daristan_beru': 0,
    'desta_muse': 1,
    'gola_dokane': 1,
    'gola_wane': 3,
    'heskif': 0,
    'kilim': 0,
    'nane_tenure': 0,
    'newroz': 0,
    'zurna': 1,
}


def convert(slug, url):
    raw = '/tmp/zk_dl_%s' % slug
    request = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = response.read()
    with open(raw, 'wb') as handle:
        handle.write(payload)

    # Soru kartı en fazla ~380pt genişlikte; 3x ekran için 1200px yeter.
    resized = raw + '_r.png'
    subprocess.run(
        ['sips', '-Z', '1200', raw, '--out', resized],
        check=True, capture_output=True,
    )
    target = os.path.join(OUT_DIR, slug + '.webp')
    subprocess.run(
        ['cwebp', '-q', '80', '-quiet', resized, '-o', target],
        check=True, capture_output=True,
    )
    for path in (raw, resized):
        if os.path.exists(path):
            os.remove(path)
    return os.path.getsize(target)


def main():
    manifest = json.load(open(MANIFEST, encoding='utf-8'))
    credits = {}
    if os.path.exists(CREDITS):
        credits = json.load(open(CREDITS, encoding='utf-8'))

    total = 0
    for slug, index in SELECTED.items():
        option = manifest[slug][index]
        size = convert(slug, option['url'])
        total += size
        credits[slug] = {
            'title': option['title'].replace('File:', ''),
            'artist': option['artist'],
            'license': option['license'],
            'source': option['descriptionurl'],
        }
        print('%-20s %6.0f KB  %-14s %s'
              % (slug, size / 1024, option['license'],
                 option['title'][5:56]))
        time.sleep(0.3)

    with open(CREDITS, 'w', encoding='utf-8') as handle:
        json.dump(credits, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write('\n')
    print('\ntoplam: %.1f MB, %d dosya' % (total / 1024 / 1024, len(SELECTED)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
