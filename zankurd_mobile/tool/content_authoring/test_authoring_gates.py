"""İçerik üretim araçlarının kapı davranışı (GPT-6 Pro alan 8 bulguları).

Çalıştırma: cd tool/content_authoring && python3 -m unittest test_authoring_gates
Her test, bir kapının eskiden SESSİZCE geçirdiği girdiyi reddettiğini ölçer.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

import cross_check
import validate_batch
import verify_facts

HERE = pathlib.Path(__file__).resolve().parent


def satir(**ek):
    q = {
        "id": "t_0001", "category": "Ziman",
        "prompt": "Paytexta Tirkiyeyê kîjan bajar e?",
        "answers": ["Enqere", "Stenbol", "Îzmîr", "Bursa"],
        "correctAnswer": "Enqere",
        "promptTr": "Türkiye'nin başkenti hangi şehirdir?",
        "answersTr": ["Ankara", "İstanbul", "İzmir", "Bursa"],
        "correctAnswerTr": "Ankara",
        "explanation": "Enqere ji sala 1923an vir paytexta Komara Tirkiyeyê ye û navenda dewletê ye.",
        "difficulty": 2,
    }
    q.update(ek)
    return q


def hatalar(q):
    return validate_batch.Gate().check_row(q, set(), set())


class ValidateBatch(unittest.TestCase):
    def test_gecerli_satir_temiz(self):
        self.assertEqual(hatalar(satir()), [])

    def test_bool_zorluk_reddedilir(self):
        self.assertIn("bad-difficulty", hatalar(satir(difficulty=True)))

    def test_bes_sik_reddedilir(self):
        q = satir(answers=["Enqere", "Stenbol", "Îzmîr", "Bursa", "Wan"],
                  answersTr=["Ankara", "İstanbul", "İzmir", "Bursa", "Van"])
        self.assertIn("bad-option-count", hatalar(q))

    def _calistir(self, icerik):
        with tempfile.TemporaryDirectory() as d:
            yol = pathlib.Path(d) / "b.json"
            yol.write_text(json.dumps(icerik), encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(HERE / "validate_batch.py"), str(yol)],
                capture_output=True, text=True)

    def test_bos_liste_ve_eksik_questions_basarisiz(self):
        for icerik in ([], {}, {"baska": 1}):
            r = self._calistir(icerik)
            self.assertNotEqual(r.returncode, 0, msg=f"{icerik!r}: {r.stdout}")
            self.assertIn("FAIL", r.stdout)


class VerifyFacts(unittest.TestCase):
    def test_dogru_sik_metni_harften_cozulur(self):
        satir_ = {"prompt": "Soru", "explanation": "x", "correct_option": "B",
                  "option_a": "yok", "option_b": "Kurd Dagi 1923", "option_c": "", "option_d": ""}
        self.assertEqual(verify_facts.correct_text(satir_), "Kurd Dagi 1923")
        self.assertIn("1923", verify_facts.claim_text(satir_))

    def test_metin_cevap_aynen_kalir(self):
        self.assertEqual(verify_facts.correct_text({"correct_option": "Amed"}), "Amed")


class CrossCheck(unittest.TestCase):
    def test_parmak_izi_icerik_degisince_degisir_siralamada_degismez(self):
        a = {"prompt": "P", "answers": ["1", "2", "3", "4"]}
        self.assertEqual(cross_check.parmak_izi(a),
                         cross_check.parmak_izi({**a, "answers": ["4", "3", "2", "1"]}))
        self.assertNotEqual(cross_check.parmak_izi(a),
                            cross_check.parmak_izi({**a, "prompt": "Q"}))
        self.assertNotEqual(cross_check.parmak_izi(a),
                            cross_check.parmak_izi({**a, "answers": ["1", "2", "3", "X"]}))


if __name__ == "__main__":
    unittest.main()
