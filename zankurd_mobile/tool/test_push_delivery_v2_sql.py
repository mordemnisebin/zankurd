"""V2 migration sözleşme kontrolleri; ağ/veritabanı kullanmaz."""
from pathlib import Path
import re
import unittest

SQL_PATH = Path(__file__).resolve().parents[1] / "supabase/2026-10-31_push_delivery_v2.sql"


class PushDeliverySqlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = SQL_PATH.read_text(encoding="utf-8")

    def test_additive_and_disabled_by_default(self):
        self.assertNotRegex(self.sql.lower(), r"create\s+or\s+replace\s+function")
        self.assertIn("enabled boolean not null default false", self.sql)
        self.assertIn("cron.alter_job", self.sql)
        self.assertIn("active := false", self.sql)
        self.assertNotRegex(self.sql.lower(), r"update\s+public\.push_delivery_v2_config\s+set\s+enabled\s*=\s*true")
        self.assertRegex(self.sql, r"(?s)delivery_status = 'legacy'.*?claimed_at is not null")

    def test_privacy_and_age_predicates_are_preserved(self):
        for token in ("push_social", "push_duel", "interval '30 minutes'", "interval '24 hours'",
                      "b.blocker_id = p_to_user_id and b.blocked_id = p_from_user_id",
                      "b.blocker_id = p_from_user_id and b.blocked_id = p_to_user_id",
                      "nullif(btrim(pr.fcm_token), '') is not null"):
            self.assertIn(token, self.sql)

    def test_lease_ack_and_rollout_contract(self):
        for token in ("claim_push_outbox_v2", "finish_push_outbox", "claim_token = p_claim_token",
                      "interval '120 seconds'", "attempt_count >= 8", "lease_until <= v_now",
                      "last_outcome = p_outcome", "returns boolean", "for update of o skip locked"):
            self.assertIn(token, self.sql)
        self.assertIn("claimed_at is null or o.claim_token is not null", self.sql)

    def test_wake_is_statement_trigger_and_vault_only(self):
        self.assertIn("for each statement", self.sql)
        self.assertIn("referencing new table as inserted_push_jobs", self.sql)
        self.assertIn("exception when others", self.sql)
        self.assertIn("'send_push_url'", self.sql)
        self.assertIn("'cron_secret'", self.sql)
        self.assertNotRegex(self.sql, r"https?://[^\s]+")
        self.assertNotIn("raise notice", self.sql.lower())

    def test_optional_postgres_parser(self):
        try:
            from pglast import parse_sql
        except ImportError:
            self.skipTest("pglast yok; PostgreSQL parser kontrolü çalıştırılmadı")
        self.assertTrue(parse_sql(self.sql))


if __name__ == "__main__":
    unittest.main()
