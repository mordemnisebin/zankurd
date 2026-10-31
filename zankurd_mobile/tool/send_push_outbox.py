#!/usr/bin/env python3
"""FCM HTTP v1 yedek işçisi; Edge Function ile aynı lease/ack sözleşmesi.

Gerekli ortam: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
GOOGLE_APPLICATION_CREDENTIALS. OAuth claim'den önce alınır. V2 RPC yoksa
eski kalıcı claim'e dönmez. FCM kabulü ile DB ack'i atomik değildir; lease
zaman aşımı sonrası nadir tekrar mümkündür. Hiçbir gizli/ileti gövdesi loglanmaz.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from email.utils import parsedate_to_datetime
from datetime import datetime
import json
import os
import random
import sys
import time
import urllib.error
import urllib.request


def _require(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"2: gerekli ortam değişkeni eksik: {name}")
    return value


def expiry_seconds(value: object) -> int | None:
    if not isinstance(value, str) or "T" not in value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            return None
        return int(parsed.timestamp())
    except (ValueError, TypeError, OverflowError):
        return None


def build_message(job: dict, token: str, now_seconds: int | None = None) -> dict:
    data = {"job_id": job["job_id"]}
    if job.get("kind"):
        data["kind"] = job["kind"]
    metadata = job.get("data") or {}
    for field in ("room_id", "invite_id", "duel_id", "from_user_id"):
        value = metadata.get(field) if isinstance(metadata, dict) else None
        if isinstance(value, str) and value:
            data[field] = value
    urgent = job.get("kind") in ("room_invite", "friend_request", "friend_accept",
                                  "async_duel_invite", "async_duel_turn")
    now = int(time.time()) if now_seconds is None else now_seconds
    expires_at = expiry_seconds(job.get("expires_at"))
    if expires_at is None or expires_at <= now:
        raise ValueError("push_job_expired_or_invalid")
    ttl = min(300 if job.get("kind") == "room_invite" else 86400, expires_at - now)
    return {"message": {
        "token": token,
        "notification": {"title": job.get("title") or "ZanKurd", "body": job.get("body") or ""},
        "data": data,
        "android": {"priority": "HIGH" if urgent else "NORMAL", "ttl": f"{ttl}s"},
        "apns": {"headers": {"apns-priority": "10" if urgent else "5", "apns-expiration": str(now + ttl)}},
    }}


def is_unregistered(status: int, body: object) -> bool:
    if status not in (400, 404) or not isinstance(body, dict):
        return False
    error = body.get("error") or {}
    if not isinstance(error, dict) or not isinstance(error.get("details"), list):
        return False
    return any(isinstance(item, dict) and item.get("errorCode") == "UNREGISTERED"
               and item.get("@type") == "type.googleapis.com/google.firebase.fcm.v1.FcmError"
               for item in error["details"])


def retry_delay(status: int, headers: dict, attempt: int) -> int | None:
    if status not in (401, 408, 429) and not 500 <= status <= 599:
        return None
    delay = int(min(3600, 30 * 2 ** min(7, max(0, attempt - 1))) * (1 + random.random() * .2) + .999)
    if status == 429:
        delay = max(60, delay)
    retry_after = next((value for key, value in headers.items() if key.lower() == "retry-after"), None)
    if retry_after:
        try:
            seconds = int(retry_after) if retry_after.strip().isdigit() else parsedate_to_datetime(retry_after).timestamp() - time.time()
            delay = max(delay, int(seconds + .999))
        except (ValueError, TypeError, OverflowError):
            pass
    return delay


def send_fcm(job: dict, project: str, bearer: str, now_seconds: int | None = None) -> tuple:
    req = urllib.request.Request(
        f"https://fcm.googleapis.com/v1/projects/{project}/messages:send",
        data=json.dumps(build_message(job, job["fcm_token"], now_seconds=now_seconds)).encode(),
        headers={"Authorization": f"Bearer {bearer}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            # Başarılı kabulden sonra gövde okuma hatası retry üretmesin.
            return response.status, dict(response.headers), None
    except urllib.error.HTTPError as error:
        try:
            body = json.loads(error.read().decode())
        except (ValueError, OSError):
            body = None
        return error.code, dict(error.headers), body


def deliver_job(job: dict, project: str, bearer: str, finish, clear_token, now_seconds: int | None = None) -> str:
    completion = {"outcome": "skipped", "error_code": "no_token"}
    now = int(time.time()) if now_seconds is None else now_seconds
    expires_at = expiry_seconds(job.get("expires_at"))
    if expires_at is None:
        completion = {"outcome": "skipped", "error_code": "invalid_expiry"}
    elif expires_at <= now:
        completion = {"outcome": "skipped", "error_code": "expired"}
    elif job.get("fcm_token"):
        try:
            status, headers, body = send_fcm(job, project, bearer, now_seconds=now)
            if 200 <= status <= 299:
                completion = {"outcome": "sent"}
            else:
                delay = retry_delay(status, headers, job["attempt_count"])
                # Ham sunucu yanıtları/token/ileti gövdesi dışarı çıkmaz.
                completion = {"outcome": "failed" if delay is None else "retry",
                              "error_code": f"http_{status}"}
                if delay is not None:
                    completion["retry_after_seconds"] = delay
                if is_unregistered(status, body):
                    try:
                        clear_token(job, job["fcm_token"])
                    except Exception:
                        pass  # Ack yine yazılmalı.
        except Exception:
            completion = {"outcome": "retry", "error_code": "network_error",
                          "retry_after_seconds": retry_delay(503, {}, job["attempt_count"])}
    for _ in range(3):
        try:
            if finish(job, completion) is True:
                return completion["outcome"]
        except Exception:
            pass  # Yalnız aynı ack, FCM yeniden gönderilmez.
    return "unsettled"


def run_jobs(rpc, project: str, bearer: str) -> dict:
    jobs = rpc("claim_push_outbox_v2", {"p_limit": 20})
    if not isinstance(jobs, list) or any(not isinstance(job, dict)
        or not isinstance(job.get("job_id"), str) or not job["job_id"]
        or not isinstance(job.get("claim_token"), str) or not job["claim_token"]
        or type(job.get("attempt_count")) is not int or job["attempt_count"] < 1
        or expiry_seconds(job.get("expires_at")) is None for job in jobs):
        raise RuntimeError("invalid_claim_contract")

    def finish(job, completion):
        return rpc("finish_push_outbox", {
            "p_job_id": job["job_id"], "p_claim_token": job["claim_token"],
            "p_outcome": completion["outcome"], "p_error_code": completion.get("error_code"),
            "p_retry_after_seconds": completion.get("retry_after_seconds"),
        })

    def clear_token(job, token):
        rpc("clear_fcm_token", {"p_user_id": job["to_user_id"], "p_token": token})

    # Claim10s + FCM10s + token temizleme10s + ack30s için120s lease payı.
    start_deadline = time.monotonic() + 55
    def worker(job):
        if time.monotonic() >= start_deadline:
            return "unsettled"  # FCM yok; lease sonrası kurtarılır.
        return deliver_job(job, project, bearer, finish, clear_token)

    with ThreadPoolExecutor(max_workers=5) as pool:
        outcomes = list(pool.map(worker, jobs))
    return {"claimed": len(jobs), **{name: outcomes.count(name) for name in
            ("sent", "skipped", "failed", "retry", "unsettled")}}


def main() -> int:
    url = _require("SUPABASE_URL").rstrip("/")
    key = _require("SUPABASE_SERVICE_ROLE_KEY")
    cred_path = _require("GOOGLE_APPLICATION_CREDENTIALS")
    if not os.path.isfile(cred_path):
        raise SystemExit("2: servis hesabı dosyası okunamadı")
    try:
        import google.auth.transport.requests  # type: ignore
        from google.oauth2 import service_account  # type: ignore
    except ImportError:
        raise SystemExit("2: google-auth kurulu değil") from None

    # OAuth başarısızken kuyruk dokunulmadan kalır.
    try:
        creds = service_account.Credentials.from_service_account_file(
            cred_path, scopes=["https://www.googleapis.com/auth/firebase.messaging"])
        creds.refresh(google.auth.transport.requests.Request())
        project = creds.project_id
        if not project or not creds.token:
            raise ValueError("oauth_missing_fields")
    except Exception:
        print("OAuth başarısız; kuyruğa dokunulmadı", file=sys.stderr)
        return 2

    def rpc(name, params):
        req = urllib.request.Request(
            f"{url}/rest/v1/rpc/{name}", data=json.dumps(params).encode(),
            headers={"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"},
            method="POST")
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                return json.loads(response.read().decode())
        except Exception:
            raise RuntimeError(f"rpc_failed:{name}") from None

    try:
        counts = run_jobs(rpc, project, creds.token)
    except Exception:
        print("V2 kuyruk alınamadı; eski claim kullanılmadı", file=sys.stderr)
        return 2
    print(json.dumps(counts))
    return 2 if counts["unsettled"] else 0


if __name__ == "__main__":
    sys.exit(main())
