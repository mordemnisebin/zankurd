#!/usr/bin/env python3
"""push_outbox kuyruğunu FCM HTTP v1 ile gönderir.

Bu betik SIRRSIZ çalışmaz. Gerekli ortam:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  GOOGLE_APPLICATION_CREDENTIALS  (Firebase servis hesabı JSON yolu)

Sır yoksa çıkış kodu 2 — kuyruğa dokunulmaz.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def _require(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(
            f"2: {name} yok. Firebase servis hesabını ve Supabase service role "
            "anahtarını sen ekle; bu betik onları repoya yazmaz."
        )
    return value


def main() -> int:
    url = _require("SUPABASE_URL").rstrip("/")
    key = _require("SUPABASE_SERVICE_ROLE_KEY")
    cred_path = _require("GOOGLE_APPLICATION_CREDENTIALS")
    if not os.path.isfile(cred_path):
        raise SystemExit(f"2: {cred_path} okunamadı")

    # Kuyruk çekilir; asıl FCM çağrısı google-auth ile yapılır.
    # Paket yoksa kullanıcıya net bırakılır.
    try:
        import google.auth.transport.requests  # type: ignore
        from google.oauth2 import service_account  # type: ignore
    except ImportError:
        raise SystemExit(
            "2: google-auth kurulu değil. `pip install google-auth` "
            "ve servis hesabından sonra tekrar çalıştır."
        ) from None

    req = urllib.request.Request(
        f"{url}/rest/v1/rpc/claim_push_outbox",
        data=json.dumps({"p_limit": 20}).encode(),
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            jobs = json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        raise SystemExit(f"claim_push_outbox başarısız: {error.read().decode()}") from error

    if not jobs:
        print("kuyruk boş")
        return 0

    scopes = ["https://www.googleapis.com/auth/firebase.messaging"]
    creds = service_account.Credentials.from_service_account_file(
        cred_path, scopes=scopes
    )
    creds.refresh(google.auth.transport.requests.Request())
    project = json.loads(open(cred_path, encoding="utf-8").read())["project_id"]
    sent = skipped = 0
    for job in jobs:
        token = (job or {}).get("fcm_token")
        if not token:
            skipped += 1
            continue
        payload = {
            "message": {
                "token": token,
                "notification": {
                    "title": job.get("title") or "ZanKurd",
                    "body": job.get("body") or "",
                },
            }
        }
        fcm = urllib.request.Request(
            f"https://fcm.googleapis.com/v1/projects/{project}/messages:send",
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {creds.token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            urllib.request.urlopen(fcm, timeout=30).read()
            sent += 1
        except urllib.error.HTTPError as error:
            print(f"FCM hata job={job.get('job_id')}: {error.read().decode()[:200]}")
    print(f"gönderilen={sent} tokensuz={skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
