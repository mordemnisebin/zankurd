# -*- coding: utf-8 -*-
"""Gövdesi Kurmancî, şıkları Türkçe kalmış soruları tümüyle Kurmancî'ye alır.

`QuestionLanguagePolicy.validate` gövde ile şıkların aynı dilde olmasını
ister; `offLanguageDistractors` ise şıkların doğru cevapla aynı dilde
olmasını. Bu 32 soru ikisini birden bozuyordu: gövde Kurmancî, doğru cevap
Türkçe tanım. 2026-07-24 denetiminde bu ailenin geri kalanı için verilen
editoryal karar Kurmancî yönündeydi; buradaki de aynı yönde tamamlanıyor.

Doğru cevap da çevrildiği için `correctAnswer` alanı da güncellenir.
"""

import importlib.util
import json
import sys

BANK = 'assets/data/offline_questions.json'

_spec = importlib.util.spec_from_file_location('fix', 'tool/fix_option_languages.py')
_fix = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_fix)

# Türkçeye çevrilmiş olanların Kurmancî aslına dönüşü.
REVERT = {v: k for k, v in _fix.KU_TR.items()}

# Zaten Türkçe olup Kurmancî karşılığı yazılmış olanlar.
EXTRA = dict(_fix.TR_KU)

# Bu ailede ilk kez çevrilenler.
EXTRA.update({
    'Baharatlı pirinç': 'birinca bi baharat',
    'Kuzey': 'Bakur',
    'Kültürel varoluş ve kimlik': 'hebûna çandî û nasname',
    'Kürt ezgi türleri': 'cureyên avazên kurdî',
    'Kürtçe şarkı veya melodi': 'stran an awaza kurdî',
    'Mîr ve Baba Şeyh': 'Mîr û Bavê Şêx',
    'Renkli, katmanlı uzun elbiseler (kras)':
        'kirasên dirêj ên rengîn û qatbiqat',
    'Sözlü kültürel miras': 'mîrateya çandî ya devkî',
    'Tarih boyunca dağlık coğrafyada yaşamayla':
        'bi jiyana di erdnîgariya çiyayî de di dirêjahiya dîrokê de',
    'UNESCO mirası tarihî höyük yerleşimi':
        'niştecihbûna girê dîrokî ya mîrateya UNESCOyê',
    'anlatı kişisi': 'kesayeta vegotinê',
    'doğu kültüründe mitolojik figür': 'fîgura mîtolojîk a çanda rojhilat',
    'geleneksel Kürt saç örgüsü modeli': 'modela kezîkirina kurdî ya kevneşopî',
    'geleneksel yedi tahıllı çorba': 'şorbeya kevneşopî ya bi heft dexlan',
    'müzisyenlere bahşiş atma geleneği':
        'kevneşopiya avêtina baxşîşê ji muzîkjenan re',
    # "sînor" yazılsaydı gövdedeki terimin kopyası olurdu; tanım verilir.
    'sınır': 'xeta ku du waran an du welatan ji hev vediqetîne',
})

# Dilden bağımsız oldukları için olduğu gibi kalanlar (tarih, özel ad,
# zaten Kurmancî olan ifadeler).
KEEP = {
    '1923', '1991', 'Lozan (1923)', 'Hewlêr', 'Melayê Cizîrî',
    'Şerê Enqereyê', 'sedsala 16em', 'sedsala 19em', 'zivistan / Berfanbar',
}


def main() -> int:
    targets = set(json.load(open(sys.argv[1], encoding='utf-8')))
    rows = json.load(open(BANK, encoding='utf-8'))
    unresolved = []
    changed = 0

    for row in rows:
        if row['id'] not in targets:
            continue

        def kurmancify(text):
            if text in KEEP:
                return text
            return REVERT.get(text) or EXTRA.get(text)

        mapped = [(a, kurmancify(a)) for a in row['answers']]
        missing = [a for a, new in mapped if new is None]
        if missing:
            unresolved.extend((row['id'], a) for a in missing)
            continue

        new_answers = [new for _, new in mapped]
        if len(set(new_answers)) != len(new_answers):
            unresolved.append((row['id'], 'ÇEVİRİ SONRASI YİNELENEN ŞIK'))
            continue

        row['correctAnswer'] = kurmancify(row['correctAnswer'])
        row['answers'] = new_answers
        changed += 1

    if not unresolved:
        with open(BANK, 'w', encoding='utf-8') as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
    print('Kurmancî\'ye alınan soru: %d' % changed)
    for qid, text in unresolved:
        print('  ÇÖZÜLMEDİ %s | %s' % (qid, text))
    return 1 if unresolved else 0


if __name__ == '__main__':
    sys.exit(main())
