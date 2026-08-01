#!/usr/bin/env python3
"""Yerel bankalardaki yabancı dilde çeldiricileri değiştirir.

`fix_offlanguage_distractors.py` ile AYNI yöntemi kullanır — uyumsuz
çeldirici, aynı yöndeki başka soruların doğru cevaplarıyla değiştirilir —
ama kusurları güçlendirilmiş sınıflandırıcıyla bulur.

Eski tarama, doğru cevabın dili belirlenemediğinde sorunun tamamını
atlıyordu; `Sandalye`, `Zarok`, `Duh` gibi ayırt edici harf taşımayan
sözlük birimleri hiç incelenmiyordu. 2026-08-01'de sunucu bankasında
185 soruda bu kusur bulununca yerel bankalar da yeniden tarandı: 40
soruda aynı kusur duruyordu.
## Sınır

Betik, bekçiden biraz DAHA agresiftir: `offline_8367` gibi gövdesi
Kurmancî, doğru cevabı Türkçe olan ve çeviri alıştırması kalıbına
uymayan sorularda bir öneri üretir ama `QuestionLanguagePolicy` onları
kusur saymaz. Sözleşme bekçidir; kuru koşuda kalan öneriyi uygulamadan
önce soruyu elle okuyun.
"""
import json, re, collections, random, statistics, sys

BANKS = ['assets/data/offline_questions.json',
         'assets/data/editorial_questions.json',
         'assets/data/community_questions.json']
QUOTE = re.compile(r'["“«]([^"”«»]{2,40})["”»]')
# Desenler `QuestionLanguagePolicy.requestedAnswerLanguage` ile AYNI
# olmalı; ayrışırsa betik, bekçinin bildirdiğini düzeltemez.
TR_ASK = re.compile(r'bi\s+Tirkî|Tirkî\s+(çi|kîjan)|wateya\s+Tirkî', re.I)
KU_ASK = re.compile(
    r'peyva\s+Kurmancî\s+ye|bi\s+Kurmancî\s+çi\s+(ye|tê)|'
    r'Hevwateya[^?]*bi\s+Kurmancî|di\s+Kurmancî\s+de\s+kîjan\s+peyv', re.I)


def asked(prompt):
    if TR_ASK.search(prompt): return 'tr'
    if KU_ASK.search(prompt): return 'ku'
    return None


def clean(w):
    w = w.strip()
    return bool(w) and ' ' not in w and '/' not in w and 2 < len(w) <= 14


POLICY = 'lib/src/services/question_language_policy.dart'


def read_policy_lexicon():
    """`QuestionLanguagePolicy`in kendi listelerini okur — tek kaynak."""
    src = open(POLICY, encoding='utf-8').read()

    def words(name):
        body = re.search(name + r'\s*=\s*\{(.*?)\}\s*;', src, re.S).group(1)
        return {w.lower() for w in re.findall(r"'([^']+)'", body)}

    amb = words('_ambiguousWords')
    # `_kurmanciVocabulary`/`_turkishVocabulary` — HASAT edilmiş içerik
    # kelimeleri. `_kurmanciWords`/`_turkishWords` ise cümle dilini ölçen
    # işlev sözcükleridir ve burada işe yaramaz; ikisi politikada bilerek
    # ayrı tutuluyor.
    return ({'ku': words('_kurmanciVocabulary') - amb,
             'tr': words('_turkishVocabulary') - amb}, amb)


def read_policy_function_words():
    """Cümle dilini ölçen işlev sözcükleri ve ayırt edici harfler."""
    src = open(POLICY, encoding='utf-8').read()

    def words(name):
        body = re.search(name + r'\s*=\s*\{(.*?)\}\s*;', src, re.S).group(1)
        return {w.lower() for w in re.findall(r"'([^']+)'", body)}

    def chars(name):
        body = re.search(name + r'\s*=\s*\{(.*?)\}\s*;', src, re.S).group(1)
        return {c for c in re.findall(r"'([^']+)'", body)}

    return ({'ku': words('_kurmanciWords'), 'tr': words('_turkishWords')},
            chars('_kurmanciChars'), chars('_turkishChars'))


def main():
    banks = {p: json.load(open(p, encoding='utf-8')) for p in BANKS}
    # Sözlük POLİTİKADAN okunur, burada yeniden kurulmaz. Aksi hâlde
    # betik ile bekçi ayrışır: betik bulamadığını düzeltemez, bekçi de
    # düzeltilmemişi bildirir. Bu, bu depoda tekrar tekrar çıkan kusur
    # deseninin ta kendisi (2026-08-01).
    LEX, AMB = read_policy_lexicon()
    seen = collections.defaultdict(set)
    synonyms = collections.defaultdict(set)
    pool = collections.defaultdict(set)

    for rows in banks.values():
        for q in rows:
            p = q.get('prompt') or ''
            a = (q.get('correctAnswer') or '').strip()
            d = asked(p)
            if not d or not a:
                continue
            m = QUOTE.search(p)
            if clean(a):
                seen[a.lower()].add(d); pool[d].add(a.lower())
            if m:
                t = m.group(1).strip()
                other = 'ku' if d == 'tr' else 'tr'
                if clean(t):
                    seen[t.lower()].add(other); pool[other].add(t.lower())
                synonyms[t.lower()].add(a.lower())

    for d in pool:
        pool[d] = sorted(w for w in pool[d] if w in LEX[d])

    FUNC, KUC, TRC = read_policy_function_words()

    def lang(text):
        """`QuestionLanguagePolicy._answerLanguage` ile aynı iki katman.

        1. Tek kelime, birebir sözlük eşleşmesi — kesin.
        2. 8+ karakterli metinlerde işlev sözcüğü + harf sezgisi.

        İkinci katman olmadan `adın ne?`, `su içmek` gibi çok kelimeli
        Türkçe şıklar Kurmancî bir sorunun içinde fark edilmiyordu:
        politika onları görüyor, betik göremiyordu ve bekçi
        düzeltilmemişi bildiriyordu.
        """
        w = text.strip().lower()
        if ' ' not in w and w not in AMB:
            if w in LEX['ku']: return 'ku'
            if w in LEX['tr']: return 'tr'
        if len(text) < 8: return None
        parts = re.findall(r"[a-zçêğıîöşûü']+", w)
        ku = sum(1 for x in parts if x in FUNC['ku'] and x not in AMB)
        tr = sum(1 for x in parts if x in FUNC['tr'] and x not in AMB)
        ku += 0.34 * sum(1 for c in w if c in KUC)
        tr += 0.34 * sum(1 for c in w if c in TRC)
        if ku == 0 and tr == 0: return None
        if ku >= tr * 1.5: return 'ku'
        if tr >= ku * 1.5: return 'tr'
        return None

    def upper_first(w):
        return ('İ' + w[1:]) if w[:1] == 'i' else (w[:1].upper() + w[1:])

    rng = random.Random(20260801)
    changed = total = 0
    for path, rows in banks.items():
        for q in rows:
            p = q.get('prompt') or ''
            answers = q.get('answers') or []
            correct = (q.get('correctAnswer') or '').strip()
            # Yön önce SORUDAN okunur; soru söylemiyorsa doğru cevabın
            # sözlükteki dilinden çıkarılır. Sıra `QuestionLanguagePolicy`
            # ile aynı olmalı, yoksa betik bekçinin bulduğunu düzeltmez.
            want = asked(p) or lang(correct)
            if not want or len(answers) < 4 or not correct:
                continue
            off = [a for a in answers if a != correct and lang(a) and lang(a) != want]
            if not off:
                continue
            # Kurmancî gövdeli bir soruda BÜTÜN şıkları Türkçeye çevirmek
            # başka bir kuralı çiğner: `QuestionLanguagePolicy.validate`
            # "Kurmancî gövde + tamamı Türkçe şıklar"ı dil karışıklığı
            # sayıyor ve çeviri alıştırması kalıbına uymayan sorularda bu
            # muafiyet yok. `offline_8367` böyle bozulmuştu — düzeltme,
            # düzelttiğinden fazlasını kırıyordu (2026-08-01).
            #
            # Ölçüt: gövde hedef dilden BAŞKA bir dildeyse ve düzeltme
            # geriye hedef dilde olmayan hiç şık bırakmıyorsa, soru
            # elle ele alınmak üzere atlanır.
            prompt_lang = lang(p) or ('ku' if KU_ASK.search(p) else None)
            if prompt_lang and prompt_lang != want and len(off) == len(
                    [a for a in answers if a != correct]):
                continue
            total += 1
            m = QUOTE.search(p)
            term = m.group(1).strip().lower() if m else ''
            keep = [a for a in answers if a not in off]
            titles = sum(1 for a in keep if a[:1].isupper())
            style = 'title' if titles * 2 >= len(keep) else 'lower'
            target_len = statistics.median([len(a) for a in keep] or [6])
            forbidden = {a.lower() for a in answers} | synonyms.get(term, set()) | {term}
            cands = [c for c in pool[want] if c not in forbidden]
            cands.sort(key=lambda c: (abs(len(c) - target_len), c))
            cands = cands[:40]
            rng.shuffle(cands)
            used = {a.lower() for a in answers}
            picks = {}
            for a in off:
                pick = next((c for c in cands if c not in used), None)
                if pick is None:
                    break
                used.discard(a.lower()); used.add(pick)
                picks[a] = upper_first(pick) if style == 'title' else pick
            if len(picks) != len(off):
                continue
            q['answers'] = [picks.get(a, a) for a in answers]
            changed += 1

    if '--apply' in sys.argv:
        for path, rows in banks.items():
            with open(path, 'w', encoding='utf-8') as fh:
                json.dump(rows, fh, ensure_ascii=False, indent=2)
                fh.write('\n')
        print(f'uygulandı: {changed}/{total} soru')
    else:
        print(f'kuru koşu: {changed}/{total} soru düzeltilebilir '
              f'(uygulamak için --apply)')


if __name__ == '__main__':
    main()
