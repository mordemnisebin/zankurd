# -*- coding: utf-8 -*-
"""Her kavram için lisansı uygun adayları toplar ve küçük önizlemelerini indirir.

Otomatik seçime güvenilemeyeceği 2026-07-26'da iki kez görüldü: serbest
arama "Gola Wanê" için Fransa'daki Salagou gölünü, kategori taraması
"erbane" için Bella Coola yerlilerinin fotoğrafını ilk sıraya koydu.
Yanlış fotoğraf, fotoğrafsızlıktan kötüdür — oyuncuyu yanlış çağrışıma
iter ve kültürel olarak yanlış şey öğretir.

Bu yüzden akış üç adımlı: burada adaylar toplanır, `contact_sheet` testi
onları tek karede çizer, seçim gözle yapılır.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch_commons_images import CONCEPTS, candidates  # noqa: E402

THUMBS = '/tmp/zk_commons'
MANIFEST = '/tmp/zk_commons/manifest.json'
UA = 'ZanKurd/1.0 (educational quiz app; contact nisebinbawer47@gmail.com)'
PER_CONCEPT = 4


# Önizleme URL'si elle kurulamıyor: Commons yalnız kendi listelediği
# thumbnail boyutlarını sunuyor ve elle türetilen adresleri 400 ile
# reddediyor. Doğrusu API'den `iiurlwidth` ile `thumburl` istemek.


def main():
    os.makedirs(THUMBS, exist_ok=True)
    manifest = {}
    WAVE2_ONLY = {
        'kela_hewlere2', 'ehmede_xani2', 'ishak_pasa2', 'colemerg2', 'merdin',
        'riha', 'herema_wane', 'dolma', 'dahol2', 'tembur2', 'bilur2',
        'zurna2', 'gele_kurd', 'jinen_kurd', 'meren_kurd', 'newroz2',
        'govend2', 'amuren_muzike', 'berf',
    }
    for slug, source in CONCEPTS.items():
        if slug not in WAVE2_ONLY:
            continue
        try:
            options = candidates(source)[:PER_CONCEPT]
        except Exception as error:
            print('%-20s HATA %s' % (slug, error))
            continue
        kept = []
        for index, option in enumerate(options):
            path = os.path.join(THUMBS, '%s_%d.jpg' % (slug, index))
            try:
                request = urllib.request.Request(
                    option.get('thumburl') or option['url'],
                    headers={'User-Agent': UA},
                )
                with urllib.request.urlopen(request, timeout=45) as response:
                    data = response.read()
                with open(path, 'wb') as handle:
                    handle.write(data)
            except Exception as error:
                print('   önizleme alınamadı: %s (%s)' % (option['title'], error))
                continue
            option['thumb'] = path
            kept.append(option)
            time.sleep(0.3)
        if kept:
            manifest[slug] = kept
        print('%-20s %d aday' % (slug, len(kept)))

    with open(MANIFEST, 'w', encoding='utf-8') as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=1)
    print('\nkavram: %d | toplam aday: %d'
          % (len(manifest), sum(len(v) for v in manifest.values())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
