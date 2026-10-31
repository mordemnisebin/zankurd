import unittest
from unittest.mock import patch

import send_push_outbox as sender


JOB = {"job_id": "j", "claim_token": "lease", "attempt_count": 1,
       "to_user_id": "u", "kind": "room_invite", "title": "ZanKurd",
       "body": "body", "fcm_token": "token", "expires_at": "2100-01-01T00:00:00Z", "data": {"room_id": "r", "invite_id": "i"}}


class PushOutboxTest(unittest.TestCase):
    def test_payload_delivery_metadata(self):
        message = sender.build_message(JOB, "token", now_seconds=1000)["message"]
        self.assertEqual(message["data"], {"job_id": "j", "kind": "room_invite", "room_id": "r", "invite_id": "i"})
        self.assertEqual(message["android"], {"priority": "HIGH", "ttl": "300s"})
        self.assertEqual(message["apns"]["headers"]["apns-expiration"], "1300")

    def test_success_ack_error_only_retries_ack(self):
        calls = []
        def finish(_job, result):
            calls.append(result)
            raise OSError("offline")
        with patch.object(sender, "send_fcm", return_value=(200, {}, None)) as send:
            result = sender.deliver_job(JOB, "project", "bearer", finish, lambda *_: True)
        self.assertEqual(result, "unsettled")
        self.assertEqual(send.call_count, 1)
        self.assertEqual([r["outcome"] for r in calls], ["sent"] * 3)

    def test_network_and_503_are_persisted_retries(self):
        results = []
        def finish(_job, result):
            results.append(result)
            return True
        with patch.object(sender, "send_fcm", side_effect=OSError("offline")):
            self.assertEqual(sender.deliver_job(JOB, "p", "b", finish, lambda *_: True), "retry")
        with patch.object(sender, "send_fcm", return_value=(503, {"Retry-After": "120"}, None)):
            sender.deliver_job(JOB, "p", "b", finish, lambda *_: True)
        self.assertEqual(results[0]["outcome"], "retry")
        self.assertEqual(results[1]["retry_after_seconds"], 120)

    def test_unknown_v2_never_falls_back_to_destructive_claim(self):
        names = []
        def rpc(name, _params):
            names.append(name)
            raise RuntimeError("rpc missing")
        with self.assertRaises(RuntimeError):
            sender.run_jobs(rpc, "p", "b")
        self.assertEqual(names, ["claim_push_outbox_v2"])

    def test_old_lease_budget_does_not_start_another_send(self):
        with patch.object(sender.time, "monotonic", side_effect=[0, 60]), patch.object(sender, "send_fcm") as send:
            counts = sender.run_jobs(lambda *_: [JOB], "p", "b")
        self.assertEqual(counts["unsettled"], 1)
        send.assert_not_called()

    def test_401_is_retry_but_403_is_terminal(self):
        outcomes = []
        def finish(_job, completion):
            outcomes.append(completion["outcome"])
            return True
        for status in (401, 403):
            with patch.object(sender, "send_fcm", return_value=(status, {}, None)):
                sender.deliver_job(JOB, "p", "b", finish, lambda *_: True)
        self.assertEqual(outcomes, ["retry", "failed"])

    def test_expiry_limits_ttl_and_skips_stale_work_before_fcm(self):
        job = {**JOB, "expires_at": "1970-01-01T00:16:41+00:00"}
        message = sender.build_message(job, "token", now_seconds=1000)["message"]
        self.assertEqual(message["android"]["ttl"], "1s")
        self.assertEqual(message["apns"]["headers"]["apns-expiration"], "1001")
        outcomes = []
        def finish(_job, completion):
            outcomes.append(completion)
            return True
        with patch.object(sender, "send_fcm") as send:
            result = sender.deliver_job(job, "p", "b", finish, lambda *_: True, now_seconds=1002)
        send.assert_not_called()
        self.assertEqual(result, "skipped")
        self.assertEqual(outcomes, [{"outcome": "skipped", "error_code": "expired"}])

    def test_retry_and_55_second_worker_wait_do_not_extend_expiry(self):
        job = {**JOB, "expires_at": "1970-01-01T00:17:30Z"}
        self.assertEqual(sender.build_message(job, "t", now_seconds=1000)["message"]["android"]["ttl"], "50s")
        self.assertEqual(sender.build_message(job, "t", now_seconds=1049)["message"]["android"]["ttl"], "1s")
        with patch.object(sender.time, "time", return_value=1055), patch.object(sender, "send_fcm") as send:
            result = sender.deliver_job(job, "p", "b", lambda *_: True, lambda *_: True)
        send.assert_not_called()
        self.assertEqual(result, "skipped")

    def test_invalid_or_missing_expiry_contract_stops_before_send(self):
        for expiry in (None, "invalid", "2026-10-31T12:00:00"):
            job = {**JOB, "expires_at": expiry}
            with patch.object(sender, "send_fcm") as send, self.assertRaises(RuntimeError):
                sender.run_jobs(lambda *_: [job], "p", "b")
            send.assert_not_called()

    def test_unregistered_is_specific_and_ack_requires_true(self):
        self.assertFalse(sender.is_unregistered(404, None))
        body = {"error": {"details": [{"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
                                       "errorCode": "UNREGISTERED"}]}}
        self.assertTrue(sender.is_unregistered(404, body))
        with patch.object(sender, "send_fcm", return_value=(200, {}, None)):
            self.assertEqual(sender.deliver_job(JOB, "p", "b", lambda *_: None, lambda *_: True), "unsettled")


if __name__ == "__main__":
    unittest.main()
