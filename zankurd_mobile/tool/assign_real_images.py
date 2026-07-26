# -*- coding: utf-8 -*-
"""İndirilen gerçek fotoğrafları ilgili sorulara bağlar.

Eşleme dar tutulur: bir soru ancak gövdesi konuyu açıkça anıyorsa fotoğraf
alır. Yanlış fotoğraf, fotoğrafsızlıktan kötüdür — oyuncuya yanlış şey
öğretir. Doğru/yanlış soruları da dışarıda: o ailede gövde terimi
tanımıyla birlikte verir, konuyu resmeden bir fotoğraf tanımın doğru olup
olmadığını konuyu bilmeden karşılaştırmayı mümkün kılar.
"""

import json
import re
import sys

BANK = 'assets/data/offline_questions.json'

# slug: gövdede aranan terimler.
#
# Listeler bilerek geniş: bir fotoğraf, aynı konuyu anan bütün sorulara
# hizmet eder. İlk sürümde dar tutulmuşlardı ve 14 fotoğraf yalnız 70
# soruya bağlanabilmişti; oysa aynı fotoğraf kavramın eşanlamlılarında da
# doğru (2026-07-26).
MATCHES = {
    'ciyaye_agiri': ['çiyayê agirî', 'agirî', 'serhildanên agirî',
                     'çiyayê tendûrekê'],
    'ciyayen_zagros': ['zagros', 'çiyayên zagrosê', 'rêzeçiyayên zagrosê',
                       'çiya', 'çiyayê halgurdê', 'lûtke'],
    'ciyayen_munzur': ['mûnzûr', 'çiyayên mûnzûrê', 'geliyê mûnzûrê',
                       'çiyayên bîngolê', 'newal', 'gelî', 'geliyê botan'],
    'gola_wane': ['gola wanê', 'gol'],
    'gola_dokane': ['gola dokanê', 'gola derbendîxanê', 'bendav'],
    'ava_zape': ['ava zapê', 'geliyê zapê', 'zapa', 'çemê', 'çem',
                 'çemê dîcleyê', 'çemê firatê', 'çemê garzanê',
                 'çemê xabûrê', 'dîcle', 'firat'],
    'desta_muse': ['deşta mûşê', 'deşt', 'deşta amedê', 'deşta hewlêrê',
                   'deşta sêwregê', 'deşta şehrezorê'],
    'daristan_beru': ['daristan', 'berû', 'dar'],
    'heskif': ['heskîf', 'bajarê kevnar', 'kel', 'kela'],
    'newroz': ['newroz', 'cejn', 'sersal', 'agir', 'pîrozkirina cejnê'],
    # 'destmal' halay mendilidir, kilim değil; fotoğraf dokuma gösteriyor.
    'kilim': ['kilim', 'kilimên kurdî', 'kilim motifleri', 'motîf', 'tevn',
              'hunera destan'],
    'cilubergen_kurdi': ['cilûberg', 'kiras', 'şal û şapik', 'kelaş',
                         'serzêr', 'kofî', 'cilûbergên herêmî'],
    'nane_tenure': ['nanê tenûrê', 'tenûr', 'nan', 'xwarin', 'pêjgeh',
                    'mitbax', 'dolma', 'şorbe'],
    # Fotoğraf bir zurna çalanı gösteriyor: bilûr, tembûr ya da def sorusuna
    # konursa oyuncuya yanlış çalgıyı öğretir. Liste yalnız bu fotoğrafın
    # gerçekten gösterdiği şeyle sınırlı (2026-07-26 gözle denetim).
    'zurna': ['zurna', 'dahol', 'govend', 'dîlan', 'stranên govendê'],
}


def main():
    rows = json.load(open(BANK, encoding='utf-8'))
    credits = json.load(open('assets/data/image_credits.json', encoding='utf-8'))
    missing = [slug for slug in MATCHES if slug not in credits]
    if missing:
        print('künyesi olmayan görsel: %s' % missing)
        return 1

    assigned = 0
    for row in rows:
        if (row.get('imageUrl') or '').strip():
            continue
        if row.get('type') == 'trueFalse':
            continue
        prompt = row['prompt'].lower()
        best = None
        best_len = 0
        for slug, terms in MATCHES.items():
            for term in terms:
                pattern = r'(?<![\wçğıöşüîêû])%s(?![\wçğıöşüîêû])' % re.escape(term)
                if re.search(pattern, prompt) and len(term) > best_len:
                    best, best_len = slug, len(term)
        if best is None:
            continue
        row['imageUrl'] = 'asset://assets/question_images/%s.webp' % best
        row['type'] = 'visual'
        assigned += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    total = len(rows)
    with_image = sum(1 for row in rows if (row.get('imageUrl') or '').strip())
    print('fotoğraf bağlanan soru: %d' % assigned)
    print('görselli soru: %d/%d (%%%.1f)'
          % (with_image, total, with_image * 100 / total))
    return 0


if __name__ == '__main__':
    sys.exit(main())
