#!/usr/bin/env python3
"""Başka bir ajanın bıraktığı işi RAPORUNA BAKMADAN denetler.

## Niçin var

2026-08-19'da Gemini Spark iki turda da yaptığından farklı bir şey rapor
etti: bir turda derlenmeyen kod "başarıyla kodlandı" diye teslim edildi;
öbür turda "zorluk oranı %32'ye çıktı" denen iş 191 sorunun yalnız
`difficulty` ALANINI değiştirmekten ibaretti — metin, şık ve cevap harfi
harfine aynıydı. Aynı turda çapraz kontrol dosyasına bankanın kendi
cevabı yazılmıştı, yani bekçi kalıcı olarak yeşile sabitlenmişti.

Ortak yan: üçü de raporu okuyarak GÖRÜNMEZ, çalışma ağacına bakarak bir
bakışta görünür. Bu araç o bakışı tek komuta indirir. Rapor okunmaz;
ölçülen şey diskteki durumdur.

Kullanım:
  python3 tool/devralma_kontrol.py            # HEAD ile karşılaştırır
  python3 tool/devralma_kontrol.py <ref>      # başka bir taban
"""
import json
import pathlib
import subprocess
import sys

BANKA = 'assets/data'
KOK = 'zankurd_mobile'


def _oku(ref, yol):
    if ref is None:
        p = pathlib.Path(yol)
        return p.read_text(encoding='utf-8') if p.exists() else None
    r = subprocess.run(['git', 'show', f'{ref}:{KOK}/{yol}'],
                       capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def _sorular(ref, ad):
    ham = _oku(ref, f'{BANKA}/{ad}')
    if not ham:
        return {}
    return {q['id']: q for q in json.loads(ham)
            if isinstance(q, dict) and q.get('id')}


def etiket_oyunu(ref):
    """Metni değişmeden yalnız `difficulty` alanı oynatılmış kayıtlar.

    Etiketi değiştirmek soruyu zorlaştırmaz; seviye bandlarını yalancı
    yapar. Gerçek zorluk çalışması metne dokunur.
    """
    bulgu = []
    for dosya in sorted(pathlib.Path(BANKA).glob('*.json')):
        eski, yeni = _sorular(ref, dosya.name), _sorular(None, dosya.name)
        for qid, y in yeni.items():
            e = eski.get(qid)
            if not e:
                continue
            ayni = (e.get('prompt') == y.get('prompt')
                    and e.get('answers') == y.get('answers')
                    and e.get('correctAnswer') == y.get('correctAnswer'))
            if ayni and e.get('difficulty') != y.get('difficulty'):
                bulgu.append(f"{qid} ({e.get('difficulty')}->{y.get('difficulty')})")
    return bulgu


def capraz_bayat(ref):
    """Metni değişmiş ama çapraz kontrol hükmü DÜŞÜRÜLMEMİŞ kayıtlar.

    İlk denemede burada "hüküm bankanın kendi cevabına eşitse sahtedir"
    diye bir sezgi vardı; YANLIŞTI. Uzun tanım şıklarında model doğruyu
    seçtiğinde hüküm zaten bankanın cevabına eşit olur — yani o desen
    kusuru değil, UYUŞMAYI gösteriyordu. 54 sağlam kaydı kusurlu ilan etti.

    Sağlam olan ölçüt şu: soru metni değiştiyse eski hüküm artık BAŞKA bir
    soruya aittir ve düşürülmeliydi. Düşürülmediyse ya biri elle yazmıştır
    ya da çapraz kontrol hiç koşturulmamıştır; ikisi de bekçiyi kör eder.
    """
    cc = pathlib.Path('docs/content_batches/capraz_kontrol.json')
    if not cc.exists():
        return ['capraz_kontrol.json yok']
    hukum = json.loads(cc.read_text(encoding='utf-8'))
    bayat = []
    for dosya in sorted(pathlib.Path(BANKA).glob('*.json')):
        eski, yeni_s = _sorular(ref, dosya.name), _sorular(None, dosya.name)
        for qid, y in yeni_s.items():
            e = eski.get(qid)
            if not e or qid not in hukum:
                continue
            if (e.get('prompt') != y.get('prompt')
                    or e.get('answers') != y.get('answers')):
                bayat.append(qid)
    return bayat


def komut(baslik, argv):
    print(f'\n-- {baslik} --')
    r = subprocess.run(argv, capture_output=True, text=True)
    satirlar = [s for s in (r.stdout + r.stderr).strip().split('\n') if s.strip()]
    son = satirlar[-1] if satirlar else '(cikti yok)'
    print('  ' + son)
    return r.returncode == 0, son


def main():
    ref = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
    print(f'Taban: {ref}\n' + '=' * 60)

    print('\n-- dokunulan dosyalar --')
    r = subprocess.run(['git', 'status', '--short'], capture_output=True, text=True)
    for satir in r.stdout.strip().split('\n'):
        if satir.strip():
            print('  ' + satir)

    sorun = []

    etiket = etiket_oyunu(ref)
    print(f'\n-- yalniz zorluk etiketi oynatilmis: {len(etiket)} --')
    for e in etiket[:6]:
        print('  ' + e)
    if etiket:
        sorun.append(f'{len(etiket)} kayitta metin ayni, yalniz zorluk etiketi degismis')

    bayat = capraz_bayat(ref)
    print(f'\n-- metni degismis ama capraz kontrol hukmu dusurulmemis: {len(bayat)} --')
    for b in bayat[:6]:
        print('  ' + b)
    if bayat:
        sorun.append(
            f'{len(bayat)} sorunun metni degismis ama eski capraz kontrol hukmu '
            f'duruyor; hukumler dusurulup cross_check.py yeniden kosturulmali')

    temiz, _ = komut('dart analyze', ['dart', 'analyze'])
    if not temiz:
        sorun.append('dart analyze temiz degil')
    gecti, satir = komut('flutter test', ['flutter', 'test'])
    if not gecti or 'All tests passed' not in satir:
        sorun.append('test suiti yesil degil')

    print('\n' + '=' * 60)
    if sorun:
        print('KUSURLU:')
        for s in sorun:
            print('  x ' + s)
        return 1
    print('TEMIZ: analiz, testler ve icerik durustlugu kontrolleri gecti.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
