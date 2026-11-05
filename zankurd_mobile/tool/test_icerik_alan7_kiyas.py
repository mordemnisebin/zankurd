"""icerik_alan7_canli_kiyas.py birim testleri (ağ yok, canlı yok)."""
import json
import unittest

import icerik_alan7_canli_kiyas as k


class KiyasTests(unittest.TestCase):
    def test_hedefler_gocle_ayni_sayida(self):
        rows = k.load_targets()
        self.assertEqual(len(rows), 375)  # 170 yerel kimlikli + 205 yalniz sunucu
        self.assertEqual(sum(r["kaynak"] == "server" for r in rows), 205)
        self.assertTrue(all(len(r["id"]) == 36 for r in rows))

    def test_sql_salt_okunur(self):
        sql = k.build_sql(k.load_targets())
        self.assertIn("begin read only;", sql)
        self.assertTrue(sql.rstrip().endswith("rollback;"))
        low = sql.lower()
        for yasak in ("insert into public", "update public", "delete from", "commit"):
            self.assertNotIn(yasak, low)

    def test_tirnakli_deger_kaybolmaz(self):
        ornek = "  ('11111111-1111-1111-1111-111111111111','x_1','prompt','Bu ''eski''','Bu ''yeni''','json'),\n"
        sql = "insert into _hedef (a) values\n" + ornek.rstrip(",\n") + ";\n"
        rows = k.load_targets(sql)
        self.assertEqual(rows[0]["eski"], "Bu 'eski'")
        self.assertEqual(rows[0]["yeni"], "Bu 'yeni'")

    def test_rapor_yalniz_atlananlari_listeler(self):
        rows = [
            {"id": "a", "yerel": "x_1", "sutun": "prompt", "kaynak": "json", "eski": "E", "yeni": "Y",
             "durum": "farkli", "canli": "Y2"},
            {"id": "a", "yerel": "x_1", "sutun": "explanation", "kaynak": "json", "eski": "E", "yeni": "Y",
             "durum": "atla", "canli": "E"},
            {"id": "b", "yerel": "x_2", "sutun": "prompt", "kaynak": "json", "eski": "E", "yeni": "Y",
             "durum": "zaten", "canli": "Y"},
        ]
        out = k.report(rows, {"x_1": {"prompt": "Y2", "explanation": "E"}})
        lines = out.strip().split("\n")
        self.assertEqual(len(lines), 3)  # baslik + 2 (zaten listelenmez)
        self.assertIn("canli=yerel", lines[1])
        self.assertIn("canli=eski", lines[2])

    def test_canli_cikti_sarmalayicidan_bulunur(self):
        rows = [{"yerel": "x", "durum": "zaten"}]
        self.assertEqual(k.find_rows({"rows": [{"alan7_kiyas": json.dumps(rows)}]}), rows)


if __name__ == "__main__":
    unittest.main()
