// deno test supabase/functions/send-push/lib_test.ts
import {
  base64UrlEncode,
  buildFcmMessage,
  deliverPushJob,
  fcmErrorCode,
  isUnregistered,
  parseServiceAccount,
  pemToDer,
  retryAfterSeconds,
  shouldClaimNextBatch,
  signServiceAccountJwt,
  timingSafeEqual,
} from "./lib.ts";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

function b64urlToBytes(s: string) {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const raw = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
}

Deno.test("RS256 JWT: başlık, iddialar ve imza doğrulanır", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  let b64 = btoa(String.fromCharCode(...pkcs8));
  b64 = b64.replace(/(.{64})/g, "$1\n");
  // Gizli değişkende sık görülen biçim: satır sonları "\n" kaçışı olarak.
  const pem = `-----BEGIN PRIVATE KEY-----\n${b64}\n-----END PRIVATE KEY-----\n`
    .replace(/\n/g, "\\n");

  const account = parseServiceAccount(JSON.stringify({
    client_email: "svc@proje.iam.gserviceaccount.com",
    private_key: pem,
    project_id: "proje",
  }));
  assert(
    account.token_uri === "https://oauth2.googleapis.com/token",
    "varsayılan token_uri",
  );

  const jwt = await signServiceAccountJwt(account, "scope-x", 1_000_000);
  const [h, p, s] = jwt.split(".");
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(h)));
  const claims = JSON.parse(new TextDecoder().decode(b64urlToBytes(p)));
  assert(header.alg === "RS256" && header.typ === "JWT", "başlık");
  assert(
    claims.iss === account.client_email && claims.scope === "scope-x",
    "iss/scope",
  );
  assert(claims.aud === account.token_uri, "aud");
  assert(claims.iat === 1_000_000 && claims.exp === 1_003_600, "iat/exp");
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pair.publicKey,
    b64urlToBytes(s),
    new TextEncoder().encode(`${h}.${p}`),
  );
  assert(ok, "imza doğrulanamadı");
});

Deno.test("servis hesabı eksik alanı adıyla bildirir, değeri sızdırmaz", () => {
  let message = "";
  try {
    parseServiceAccount(
      JSON.stringify({ client_email: "a@b", project_id: "p" }),
    );
  } catch (e) {
    message = (e as Error).message;
  }
  assert(message === "service_account_missing:private_key", message);
  let notJson = "";
  try {
    parseServiceAccount("{gizli");
  } catch (e) {
    notJson = (e as Error).message;
  }
  assert(notJson === "service_account_not_json", notJson);
});

Deno.test("FCM iletisi python betiğiyle aynı biçimde", () => {
  const job = {
    job_id: "j",
    to_user_id: "u",
    kind: "async_duel_invite",
    title: "ZanKurd",
    body: "metin",
    fcm_token: "t",
    expires_at: "2100-01-01T00:00:00Z",
  };
  const m = buildFcmMessage(job, "t").message as Record<string, unknown>;
  assert(m.token === "t", "token");
  assert(
    JSON.stringify(m.notification) ===
      JSON.stringify({ title: "ZanKurd", body: "metin" }),
    "notification",
  );
  assert(
    JSON.stringify(m.data) ===
      JSON.stringify({ job_id: "j", kind: "async_duel_invite" }),
    "data.kind",
  );
  const noKind = buildFcmMessage({
    ...job,
    kind: null,
    title: null,
    body: null,
  }, "t")
    .message as Record<string, unknown>;
  assert(
    (noKind.data as { job_id: string }).job_id === "j",
    "kind yokken de iş kimliği",
  );
  assert(
    (noKind.notification as { title: string }).title === "ZanKurd",
    "başlık yedeği",
  );
});

Deno.test("UNREGISTERED sınıflaması", () => {
  assert(!isUnregistered(404, null), "genel 404 token silmez");
  assert(
    !isUnregistered(400, { error: { status: "NOT_FOUND" } }),
    "genel NOT_FOUND token silmez",
  );
  assert(
    isUnregistered(400, {
      error: {
        status: "X",
        details: [{
          "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
          errorCode: "UNREGISTERED",
        }],
      },
    }),
    "details",
  );
  assert(
    !isUnregistered(400, { error: { status: "INVALID_ARGUMENT" } }),
    "INVALID_ARGUMENT",
  );
  assert(!isUnregistered(500, null), "500");
  assert(
    fcmErrorCode({ error: { status: "UNAVAILABLE" } }) === "UNAVAILABLE",
    "kod",
  );
  assert(fcmErrorCode(null) === "unknown", "kod yok");
});

Deno.test("timingSafeEqual ve base64url/pem yardımcıları", () => {
  assert(timingSafeEqual("abc", "abc"), "eşit");
  assert(!timingSafeEqual("abc", "abd"), "farklı");
  assert(!timingSafeEqual("abc", "abcd"), "uzunluk");
  assert(!timingSafeEqual("", "x"), "boş");
  assert(base64UrlEncode(new Uint8Array([251, 255])) === "-_8", "base64url");
  const der = pemToDer("-----BEGIN X-----\\nAQID\\n-----END X-----");
  assert(der.length === 3 && der[0] === 1 && der[2] === 3, "pem");
});

Deno.test("teslimat meta verisi ve acil davet ömrü taşınır", () => {
  const job = {
    job_id: "j",
    to_user_id: "u",
    kind: "room_invite",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: "2100-01-01T00:00:00Z",
    data: { room_id: "r", invite_id: "i", kind: "evil", other: 4 },
  };
  const message = buildFcmMessage(job, "t", 1000).message as Record<
    string,
    any
  >;
  assert(
    message.data.job_id === "j" && message.data.kind === "room_invite",
    "iş kimliği/türü",
  );
  assert(
    message.data.room_id === "r" && message.data.invite_id === "i",
    "yönlendirme",
  );
  assert(!("other" in message.data), "yalnız izinli dize alanları");
  assert(
    message.android.priority === "HIGH" && message.android.ttl === "300s",
    "Android acil TTL",
  );
  assert(message.apns.headers["apns-priority"] === "10", "APNs görünür uyarı");
  assert(message.apns.headers["apns-expiration"] === "1300", "APNs TTL");
});

Deno.test("geçici hata kalıcı kuyrukta yeniden denenir, başarılı iş tekrar kuyruğa yazılmaz", async () => {
  const outcomes: Array<Record<string, unknown>> = [];
  const job = {
    job_id: "j",
    claim_token: "c",
    attempt_count: 2,
    to_user_id: "u",
    kind: "room_invite",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: "2100-01-01T00:00:00Z",
  };
  const finish = async (_job: unknown, result: Record<string, unknown>) => {
    outcomes.push(result);
    return true;
  };
  const unavailable = await deliverPushJob(job, {
    send: async () =>
      new Response(JSON.stringify({ error: { status: "UNAVAILABLE" } }), {
        status: 503,
        headers: { "retry-after": "120" },
      }),
    finish,
    clearToken: async () => true,
    random: () => 0,
  });
  assert(
    unavailable === "retry" && outcomes[0].retryAfterSeconds === 120,
    "503 kalıcı retry",
  );
  outcomes.length = 0;
  let sends = 0;
  const result = await deliverPushJob(job, {
    send: async () => {
      sends++;
      return new Response("{}", { status: 200 });
    },
    finish: async (_job, outcome) => {
      outcomes.push(outcome);
      throw new Error("db unavailable");
    },
    clearToken: async () => true,
    random: () => 0,
  });
  assert(result === "unsettled" && sends === 1, "FCM başarı yalnız bir kez");
  assert(
    outcomes.length === 3 && outcomes.every((o) => o.outcome === "sent"),
    "ack yeniden denemesi asla requeue değil",
  );
});

Deno.test("ağ hatası retry; geçersiz token temizleme yalnız token'a özgü kod ile", async () => {
  const job = {
    job_id: "j",
    claim_token: "c",
    attempt_count: 1,
    to_user_id: "u",
    kind: "friend_request",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: "2100-01-01T00:00:00Z",
  };
  const outcomes: Array<Record<string, unknown>> = [];
  let cleared = 0;
  const deps = {
    finish: async (_j: unknown, outcome: Record<string, unknown>) => {
      outcomes.push(outcome);
      return true;
    },
    clearToken: async () => {
      cleared++;
      return true;
    },
    random: () => 0,
  };
  await deliverPushJob(job, {
    ...deps,
    send: async () => {
      throw new TypeError("network");
    },
  });
  assert(outcomes[0].outcome === "retry", "ağ retry");
  await deliverPushJob(job, {
    ...deps,
    send: async () => new Response("{}", { status: 404 }),
  });
  assert(
    cleared === 0 && outcomes[1].outcome === "failed",
    "proje 404 jeton silmez",
  );
  await deliverPushJob(job, {
    ...deps,
    send: async () =>
      new Response(
        JSON.stringify({
          error: {
            details: [{
              "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
              errorCode: "UNREGISTERED",
            }],
          },
        }),
        { status: 404 },
      ),
  });
  assert(
    Number(cleared) === 1 && outcomes[2].outcome === "failed",
    "UNREGISTERED token temizler",
  );
});

Deno.test("429 en az bir dakika; Retry-After HTTP tarihi; 4xx terminal", () => {
  assert(retryAfterSeconds(429, null, 1, null, 0, 0) === 60, "429 minimum");
  assert(
    retryAfterSeconds(503, null, 1, "Thu, 01 Jan 1970 00:02:00 GMT", 0, 0) ===
      120,
    "HTTP tarih",
  );
  assert(
    retryAfterSeconds(
      400,
      { error: { status: "INVALID_ARGUMENT" } },
      1,
      null,
      0,
      0,
    ) === null,
    "4xx terminal",
  );
});

Deno.test("401 geçici retry olur, 403 terminal kalır", async () => {
  const job = {
    job_id: "j",
    claim_token: "c",
    attempt_count: 1,
    to_user_id: "u",
    kind: "friend_request",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: "2100-01-01T00:00:00Z",
  };
  const outcomes: string[] = [];
  for (const status of [401, 403]) {
    const result = await deliverPushJob(job, {
      send: async () => new Response("{}", { status }),
      finish: async (_job, completion) => {
        outcomes.push(completion.outcome);
        return true;
      },
      clearToken: async () => {
        throw new Error("token silinmemeli");
      },
      random: () => 0,
    });
    assert(result === (status === 401 ? "retry" : "failed"), "auth sınıflama");
  }
  assert(outcomes.join(",") === "retry,failed", "sınırlandırılmış auth retry");
});

Deno.test("mutlak ömür: son1 saniye TTL1; geçmiş iş FCM çağırmadan skipped", async () => {
  const job = {
    job_id: "j",
    claim_token: "c",
    attempt_count: 2,
    to_user_id: "u",
    kind: "room_invite",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: new Date(1001 * 1000).toISOString(),
  };
  const message = buildFcmMessage(job, "t", 1000).message;
  assert(message.android.ttl === "1s", "kalan tek saniye");
  assert(
    message.apns.headers["apns-expiration"] === "1001",
    "mutlak APNs expiry",
  );
  let sends = 0;
  let skipped = 0;
  const result = await deliverPushJob(job, {
    nowSeconds: () => 1002,
    send: async () => {
      sends++;
      return new Response("{}", { status: 200 });
    },
    finish: async (_job, completion) => {
      if (
        completion.outcome === "skipped" && completion.errorCode === "expired"
      ) skipped++;
      return true;
    },
    clearToken: async () => true,
  });
  assert(
    result === "skipped" && skipped === 1 && sends === 0,
    "süresi dolan iş gönderilmez",
  );
});

Deno.test("retry ve worker beklemesi mutlak ömrü uzatmaz", async () => {
  const job = {
    job_id: "j",
    claim_token: "c",
    attempt_count: 3,
    to_user_id: "u",
    kind: "room_invite",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: new Date(1050 * 1000).toISOString(),
  };
  assert(
    buildFcmMessage(job, "t", 1000).message.android.ttl === "50s",
    "ilk kalan süre",
  );
  assert(
    buildFcmMessage(job, "t", 1049).message.android.ttl === "1s",
    "retry kalan süre",
  );
  let sends = 0;
  const outcome = await deliverPushJob(job, {
    nowSeconds: () => 1055,
    send: async () => {
      sends++;
      return new Response("{}", { status: 200 });
    },
    finish: async () => true,
    clearToken: async () => true,
  });
  assert(
    outcome === "skipped" && sends === 0,
    "55sn worker bekleme sonrası expiry",
  );
});

Deno.test("henüz geçerli iş aynı saat örneğinin TTL ile gönderilir", async () => {
  const job = {
    job_id: "j",
    claim_token: "c",
    attempt_count: 1,
    to_user_id: "u",
    kind: "room_invite",
    title: null,
    body: null,
    fcm_token: "t",
    expires_at: new Date(1001 * 1000).toISOString(),
  };
  let sends = 0;
  const outcome = await deliverPushJob(job, {
    nowSeconds: () => 1000,
    send: async (_job, _token, payload) => {
      sends++;
      assert(
        payload.message.android.ttl === "1s",
        "gönderilen gerçek payload TTL",
      );
      assert(
        payload.message.apns.headers["apns-expiration"] === "1001",
        "gönderilen gerçek APNs sınırı",
      );
      return new Response("{}", { status: 200 });
    },
    finish: async () => true,
    clearToken: async () => true,
  });
  assert(outcome === "sent" && sends === 1, "geçerli iş gönderildi");
});

Deno.test("shouldClaimNextBatch: boş talep, bütçe, unsettled ve üst sınır döngüyü durdurur", () => {
  const base = {
    now: 1_000,
    deadline: 26_000,
    lastClaimed: 20,
    unsettled: 0,
    batches: 1,
  };
  assert(shouldClaimNextBatch(base), "dolu paket + bütçe varken devam");
  assert(
    shouldClaimNextBatch({ ...base, lastClaimed: null, batches: 0 }),
    "ilk talep her zaman yapılır",
  );
  assert(
    !shouldClaimNextBatch({ ...base, lastClaimed: 0 }),
    "boş talep kuyruğun bittiğini gösterir",
  );
  assert(
    !shouldClaimNextBatch({ ...base, now: 26_000 }),
    "bütçe dolunca yeni lease alınmaz",
  );
  assert(
    !shouldClaimNextBatch({ ...base, unsettled: 1 }),
    "ack'i kesinleşmeyen iş varken yeni lease alınmaz",
  );
  assert(
    !shouldClaimNextBatch({ ...base, batches: 200 }),
    "üst sınır sonsuz döngüyü keser",
  );
  assert(
    shouldClaimNextBatch({ ...base, batches: 199 }),
    "üst sınırın altında devam",
  );
});
