import json
import tempfile
import unittest
from pathlib import Path

import editorial_queue


class EditorialQueueTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "lib/src/data").mkdir(parents=True)
        (self.root / "assets/data").mkdir(parents=True)

    def tearDown(self):
        self.temp.cleanup()

    def write_manifest(self, body):
        path = self.root / "lib/src/data/question_bank_assets.dart"
        path.write_text(body, encoding="utf-8")
        return path

    def write_bank(self, name, rows):
        path = self.root / "assets/data" / name
        path.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")
        return path

    def test_commented_bank_is_excluded_and_scope_is_json_only(self):
        manifest = self.write_manifest("""
const questionBankAssets = <String>[
  'assets/data/live_questions.json',
  // 'assets/data/quarantined_questions.json',
];
""")
        self.write_bank("live_questions.json", [{"id": "live-1", "prompt": "P?"}])
        self.write_bank("quarantined_questions.json", [{"id": "hidden-1", "prompt": "H?"}])

        report = editorial_queue.build_report(self.root, manifest)

        self.assertEqual(report["scope"], "registered_json_assets_only")
        self.assertEqual(report["summary"]["bankCount"], 1)
        self.assertEqual([row["id"] for row in report["records"]], ["live-1"])

    def test_visual_without_bilingual_alt_has_top_priority_and_statuses_stay_separate(self):
        manifest = self.write_manifest("""
const questionBankAssets = <String>['assets/data/live_questions.json'];
""")
        self.write_bank("live_questions.json", [
            {
                "id": "visual-1", "prompt": "Wêne çi nîşan dide?", "type": "visual",
                "imageUrl": "asset://image.webp", "imageAltTr": "Bir görsel",
                "difficulty": 2, "metadata": {"reviewStatus": "approved"}
            },
            {
                "id": "review-1", "prompt": "Soru", "type": "multipleChoice",
                "difficulty": 1, "metadata": {"reviewStatus": "needsReview"}
            },
            {
                "id": "reject-1", "prompt": "Soru", "type": "multipleChoice",
                "difficulty": 3, "metadata": {"reviewStatus": "rejected"}
            }
        ])

        report = editorial_queue.build_report(self.root, manifest)
        rows = {row["id"]: row for row in report["records"]}

        self.assertEqual(rows["visual-1"]["priority"], "P0")
        self.assertTrue(rows["visual-1"]["imageAltMissing"])
        self.assertEqual(rows["review-1"]["reviewStatus"], "needsReview")
        self.assertEqual(rows["reject-1"]["reviewStatus"], "rejected")
        self.assertEqual(report["summary"]["reviewStatuses"]["needsReview"], 1)
        self.assertEqual(report["summary"]["reviewStatuses"]["rejected"], 1)

    def test_missing_malformed_bank_and_duplicate_id_fail(self):
        missing = self.write_manifest("""
const questionBankAssets = <String>['assets/data/missing.json'];
""")
        with self.assertRaisesRegex(editorial_queue.AuditError, "missing.json"):
            editorial_queue.build_report(self.root, missing)

        malformed_path = self.root / "assets/data/malformed.json"
        malformed_path.write_text("[{", encoding="utf-8")
        malformed = self.write_manifest("""
const questionBankAssets = <String>['assets/data/malformed.json'];
""")
        with self.assertRaisesRegex(editorial_queue.AuditError, "Malformed JSON"):
            editorial_queue.build_report(self.root, malformed)

        self.write_bank("a.json", [{"id": "same", "prompt": "A"}])
        self.write_bank("b.json", [{"id": "same", "prompt": "B"}])
        duplicate = self.write_manifest("""
const questionBankAssets = <String>[
 'assets/data/a.json', 'assets/data/b.json',
];
""")
        with self.assertRaisesRegex(editorial_queue.AuditError, "Duplicate id: same"):
            editorial_queue.build_report(self.root, duplicate)


if __name__ == "__main__":
    unittest.main()
