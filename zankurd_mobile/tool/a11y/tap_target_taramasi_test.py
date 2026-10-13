#!/usr/bin/env python3
"""`tap_target_taramasi.py` sınıflandırıcısının bekçisi.

## Kusur neydi

Taramanın tek değerli işi şu ayrımdır: **`IconButton` 44 px kısıtla
güvendedir, `InkWell` değildir.** `IconButton`ın varsayılan
`tapTargetSize`ı `MaterialTapTargetSize.padded` olduğu için `constraints`
ne derse desin vuruş alanını 48'e genişletir; `InkWell` ve
`GestureDetector`da böyle bir genişletme YOKTUR, kısıt ne diyorsa hedef
odur. Bu ayrım kaybolursa tarama iki yönde birden bozulur: ya 6 masum
`IconButton` kusur diye raporlanır, ya 8 gerçek `InkWell` bulgusu
«nasılsa Flutter genişletir» diye elenir.

## Niçin sessiz kalırdı

Sınıflandırıcı bozulsa bile tarama **çalışmaya devam eder ve bir liste
basar** — yalnız liste yanlış olur. Çıktı makul göründüğü için hata
gözle yakalanmaz; kimse 48 altı kısıtların hangisinin sarmalayanını
bilmez, listeye bakıp inanır. Kapsam dar olduğu için değil, **çıktı her
durumda inandırıcı göründüğü için** sessizdir.

İkinci sessiz nokta: 48 altı kısıtların çoğunluğu (bugün 13'ü)
`LinearProgressIndicator` kalınlığıdır, dokunma hedefi değil. Ayıklama
bozulursa gerçek bulgu gürültüde kaybolur ve tarama «çok bulgu var» diye
güvenilirliğini yitirir.

Örnekler bu depodaki gerçek çağrı biçimlerinden alındı; sentetik oldukları
için depo değiştikçe çürümezler.
"""
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))

from tap_target_taramasi import kilavuz_hukmu, sarmalayan_bul  # noqa: E402


def siniflandir(kod: str) -> str:
    """Son satırdaki kısıtın sarmalayanını döndürür."""
    satirlar = kod.strip("\n").splitlines()
    return sarmalayan_bul(satirlar, len(satirlar) - 1)


class SarmalayanTesti(unittest.TestCase):
    def test_iconbutton_padded_genisletmesi_taninir(self):
        """`IconButton` 44 kısıtla güvende — kusur diye raporlanmamalı."""
        kod = """
            child: IconButton(
              onPressed: onReport,
              icon: const Icon(AppIcons.flag, size: 16),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        """
        self.assertEqual(siniflandir(kod), "iconbutton")

    def test_inkwell_genisletme_almaz(self):
        """`InkWell`de `tapTargetSize` yok; 44 gerçek hedeftir."""
        kod = """
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AnimatedContainer(
                constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
        """
        self.assertEqual(siniflandir(kod), "dokunulabilir")

    def test_gesturedetector_de_dokunulabilir_sayilir(self):
        kod = """
            child: GestureDetector(
              onTap: widget.onSuffixIconPressed,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
        """
        self.assertEqual(siniflandir(kod), "dokunulabilir")

    def test_ilerleme_cubugu_ayiklanir(self):
        """`minHeight` burada çubuk KALINLIĞI — dokunma hedefi değil."""
        kod = """
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
        """
        self.assertEqual(siniflandir(kod), "ilerleme_cubugu")

    def test_en_yakin_sarmalayan_kazanir(self):
        """Dış `InkWell`, iç `LinearProgressIndicator`: kısıt çubuğundur.

        Kaydırılabilir bir kartın içindeki ilerleme çubuğu tam bu biçimde
        duruyor; en yakın sarmalayan alınmazsa çubuk kalınlığı dokunma
        hedefi sanılır.
        """
        kod = """
            child: InkWell(
              onTap: open,
              child: ClipRRect(
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 7,
        """
        self.assertEqual(siniflandir(kod), "ilerleme_cubugu")

    def test_sarmalayansiz_kisit_bilinmiyor_kalir(self):
        """Dokunulmayan rozet: kusur DEĞİL, ama otomatik temiz de sayılmaz."""
        kod = """
            child: Container(
              key: const ValueKey('leaderboard-friends-badge'),
              constraints: const BoxConstraints(minWidth: 18),
        """
        self.assertEqual(siniflandir(kod), "bilinmiyor")


class EsikTesti(unittest.TestCase):
    """44 iOS'un alt sınırıdır, Android'in değil — bu depodaki gelenek
    tam bu boşlukta duruyor ve «temiz» sayılırsa bulgu kaybolur."""

    def test_44_yalniz_androidi_dusurur(self):
        self.assertEqual(kilavuz_hukmu(44), "yalniz_android")

    def test_36_ikisini_de_dusurur(self):
        self.assertEqual(kilavuz_hukmu(36), "ikisi_de")

    def test_48_temiz(self):
        self.assertEqual(kilavuz_hukmu(48), "temiz")

    def test_46_hala_android_altinda(self):
        """46 «neredeyse 48» değildir; Android eşiği keskin."""
        self.assertEqual(kilavuz_hukmu(46), "yalniz_android")


if __name__ == "__main__":
    unittest.main()
