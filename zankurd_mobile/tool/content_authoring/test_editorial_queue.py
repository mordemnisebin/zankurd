import json
import hashlib
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


class ReviewedDuplicateGroupsTest(unittest.TestCase):
    setUp = EditorialQueueTest.setUp
    tearDown = EditorialQueueTest.tearDown
    write_manifest = EditorialQueueTest.write_manifest
    write_bank = EditorialQueueTest.write_bank
    def prepare(self):
        self.write_manifest("const questionBankAssets = <String>['assets/data/a.json'];")
        self.a = {"id": "a", "prompt": "Same target?", "correctAnswer": "31"}
        self.b = {"id": "b", "prompt": "Same target again?", "correctAnswer": "31"}
        self.write_bank("a.json", [self.a, self.b])
        sidecar = self.root / "tool/content_authoring/reviewed_duplicate_groups.json"
        sidecar.parent.mkdir(parents=True)
        members = [{"sourcePath": "assets/data/a.json", "id": q["id"],
                    "recordSha256": hashlib.sha256(json.dumps(q, sort_keys=True, ensure_ascii=False,
                        separators=(",", ":")).encode("utf-8")).hexdigest()} for q in [self.a, self.b]]
        sidecar.write_text(json.dumps({"schemaVersion": 1,
            "hashAlgorithm": "sha256-canonical-json-v1", "groups": [{
                "groupId": "same-objective", "rationale": "Same alphabet size objective",
                "members": members}]}))
        return sidecar

    # Break caught: silently treating reviewed groups as absent instead of showing current review.
    def test_current_group_report_preserves_both_production_records(self):
        self.prepare()
        report = editorial_queue.build_report(self.root)
        self.assertIn("reviewedDuplicateGroups", report)
        groups = report["reviewedDuplicateGroups"]
        self.assertEqual(groups["status"], "loaded")
        self.assertEqual(groups["groups"][0]["status"], "current")
        self.assertTrue(groups["groups"][0]["reviewValid"])
        self.assertEqual(report["summary"]["recordCount"], 2)
        self.assertEqual({r["id"] for r in report["records"]}, {"a", "b"})

    # Break caught: carrying a review forward after even one record's answer changes.
    def test_answer_drift_invalidates_the_whole_group(self):
        self.prepare()
        changed = {**self.b, "correctAnswer": "32"}
        self.write_bank("a.json", [self.a, changed])
        report = editorial_queue.build_report(self.root)
        self.assertIn("reviewedDuplicateGroups", report)
        group = report["reviewedDuplicateGroups"]["groups"][0]
        self.assertEqual(group["status"], "stale")
        self.assertFalse(group["reviewValid"])
        self.assertEqual([m["status"] for m in group["members"]], ["current", "changed"])

    # Break caught: counting missing/excluded members as reviewed current zero debt.
    def test_missing_member_is_reported_and_never_approved(self):
        self.prepare()
        self.write_bank("a.json", [self.a])
        report = editorial_queue.build_report(self.root)
        self.assertIn("reviewedDuplicateGroups", report)
        group = report["reviewedDuplicateGroups"]["groups"][0]
        self.assertEqual(group["status"], "stale")
        self.assertFalse(group["reviewValid"])
        self.assertEqual(group["members"][1]["status"], "missing_or_not_registered")

    def test_new_matching_prompt_is_candidate_and_does_not_join_reviewed_group(self):
        self.prepare()
        third = {"id": "c", "prompt": "  SAME target? ", "correctAnswer": "32"}
        self.write_bank("a.json", [self.a, self.b, third])
        report = editorial_queue.build_report(self.root)
        self.assertIn("reviewedDuplicateGroups", report)
        group = report["reviewedDuplicateGroups"]["groups"][0]
        self.assertEqual(len(group["members"]), 2)
        self.assertEqual(group["unreviewedPromptMatches"], [{
            "sourcePath": "assets/data/a.json", "id": "c",
            "matchesMemberId": "a", "matchKind": "normalized_prompt",
            "semanticReviewRequired": True}])

    def test_malformed_sidecar_fails_instead_of_reporting_no_groups(self):
        sidecar = self.prepare()
        sidecar.write_text('{"groups": []}')
        with self.assertRaisesRegex(editorial_queue.AuditError, "reviewed duplicate"):
            editorial_queue.build_report(self.root)


if __name__ == "__main__":
    unittest.main()
