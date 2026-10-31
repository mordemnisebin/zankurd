// send-push yardımcıları — saf işlevler (ağ ve ortam YOK), Deno testiyle
// sınanabilsin diye index.ts'ten ayrıldı. Gizli değer içermez, hiçbir şey
// günlüğe yazmaz.

export interface PushJob {
  job_id: string;
  to_user_id: string;
  kind: string | null;
  title: string | null;
  body: string | null;
  fcm_token: string | null;
  expires_at: string;
  data?: Record<string, unknown> | null;
  claim_token?: string;
  attempt_count?: number;
}

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri: string;
}

const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

export function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

export function pemToDer(pem: string) {
  // Gizli değişken tek satıra sıkıştırıldıysa "\n" kaçışları gerçek satıra çevrilir.
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

/// `FCM_SERVICE_ACCOUNT_JSON` metnini doğrular. Eksik alan hata mesajında
/// yalnız ALAN ADIYLA anılır; değer asla.
export function parseServiceAccount(raw: string): ServiceAccount {
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(raw);
  } catch (_) {
    throw new Error("service_account_not_json");
  }
  const clientEmail = parsed.client_email;
  const privateKey = parsed.private_key;
  const projectId = parsed.project_id;
  for (
    const [name, value] of [
      ["client_email", clientEmail],
      ["private_key", privateKey],
      ["project_id", projectId],
    ] as const
  ) {
    if (typeof value !== "string" || value.length === 0) {
      throw new Error(`service_account_missing:${name}`);
    }
  }
  const tokenUri = typeof parsed.token_uri === "string" && parsed.token_uri
    ? parsed.token_uri
    : DEFAULT_TOKEN_URI;
  return {
    client_email: clientEmail as string,
    private_key: privateKey as string,
    project_id: projectId as string,
    token_uri: tokenUri,
  };
}

/// Google'ın OAuth jeton uç noktasına sunulan RS256 imzalı JWT (1 saat ömürlü).
export async function signServiceAccountJwt(
  account: ServiceAccount,
  scope: string,
  nowSeconds: number = Math.floor(Date.now() / 1000),
): Promise<string> {
  const enc = new TextEncoder();
  const header = base64UrlEncode(
    enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
  );
  const payload = base64UrlEncode(
    enc.encode(
      JSON.stringify({
        iss: account.client_email,
        scope,
        aud: account.token_uri,
        iat: nowSeconds,
        exp: nowSeconds + 3600,
      }),
    ),
  );
  const signingInput = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      enc.encode(signingInput),
    ),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

/// Yalnız zaman dilimi taşıyan RPC timestamptz değeri kabul edilir.
export function validPushExpiry(value: unknown): value is string {
  return typeof value === "string" &&
    /^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:\d{2})$/.test(value) &&
    Number.isFinite(Date.parse(value));
}

/// FCM v1 verileri yalnız dize; kimlik ve tür kuyruktaki güvenilir alandan gelir.
export function buildFcmMessage(
  job: PushJob,
  token: string,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  const data: Record<string, string> = { job_id: job.job_id };
  if (job.kind) data.kind = job.kind;
  for (const key of ["room_id", "invite_id", "duel_id", "from_user_id"]) {
    const value = job.data?.[key];
    if (typeof value === "string" && value.length > 0) data[key] = value;
  }
  const urgent = [
    "room_invite",
    "friend_request",
    "friend_accept",
    "async_duel_invite",
    "async_duel_turn",
  ].includes(job.kind ?? "");
  const expiresAt = validPushExpiry(job.expires_at)
    ? Math.floor(Date.parse(job.expires_at) / 1000)
    : NaN;
  if (!Number.isFinite(expiresAt) || expiresAt <= nowSeconds) {
    throw new Error("push_job_expired_or_invalid");
  }
  const ttl = Math.min(
    job.kind === "room_invite" ? 300 : 86400,
    expiresAt - nowSeconds,
  );
  return {
    message: {
      token,
      notification: { title: job.title || "ZanKurd", body: job.body || "" },
      data,
      android: { priority: urgent ? "HIGH" : "NORMAL", ttl: `${ttl}s` },
      apns: {
        headers: {
          "apns-priority": urgent ? "10" : "5",
          "apns-expiration": `${nowSeconds + ttl}`,
        },
      },
    },
  };
}

/// FCM hata gövdesi + HTTP durumu → jeton kalıcı olarak geçersiz mi?
/// Yalnız FCM'ye özgü UNREGISTERED ayrıntısı jeton temizler; genel
/// 404/NOT_FOUND proje veya uç nokta hatası da olabilir. INVALID_ARGUMENT
/// yük hatası da olabilir, jetonu yanlışlıkla silmeyelim.
export function isUnregistered(status: number, body: unknown): boolean {
  if (status !== 404 && status !== 400) return false;
  const error =
    (body as { error?: { status?: string; details?: unknown } } | null)
      ?.error;
  if (!error) return false;

  if (Array.isArray(error.details)) {
    for (const detail of error.details) {
      if (
        (detail as { errorCode?: string; "@type"?: string })?.errorCode ===
          "UNREGISTERED" &&
        (detail as { "@type"?: string })["@type"] ===
          "type.googleapis.com/google.firebase.fcm.v1.FcmError"
      ) {
        return true;
      }
    }
  }
  return false;
}

/// Günlüğe yazılabilir kısa hata kodu (jeton/ileti içermez).
export function fcmErrorCode(body: unknown): string {
  const error = (body as { error?: { status?: string } } | null)?.error;
  return typeof error?.status === "string" ? error.status : "unknown";
}

/// Zamanlama saldırısına dayanıklı dize karşılaştırması.
export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

/// Geçici FCM hatası: 429 için en az 60 sn, diğerlerinde artan gecikme.
/// Retry-After asla aşağı yuvarlanmaz; kuyruk bu süreyi kalıcı saklar.
export function retryAfterSeconds(
  status: number,
  _body: unknown,
  attempt: number,
  retryAfter: string | null,
  nowMs = Date.now(),
  random = Math.random(),
): number | null {
  if (
    status !== 401 && status !== 429 && status !== 408 &&
    (status < 500 || status > 599)
  ) {
    return null;
  }
  const backoff = Math.min(
    3600,
    30 * 2 ** Math.min(7, Math.max(0, attempt - 1)),
  );
  let delay = Math.ceil(backoff * (1 + Math.max(0, Math.min(1, random)) * 0.2));
  if (status === 429) delay = Math.max(60, delay);
  if (retryAfter) {
    const parsed = /^\d+$/.test(retryAfter.trim())
      ? Number(retryAfter)
      : (Date.parse(retryAfter) - nowMs) / 1000;
    if (Number.isFinite(parsed)) delay = Math.max(delay, Math.ceil(parsed));
  }
  return delay;
}

export type PushOutcome = "sent" | "skipped" | "failed" | "retry";
export interface PushCompletion {
  [key: string]: unknown;
  outcome: PushOutcome;
  errorCode?: string;
  retryAfterSeconds?: number;
}
export interface DeliveryDependencies {
  send: (
    job: PushJob,
    token: string,
    payload: ReturnType<typeof buildFcmMessage>,
  ) => Promise<Response>;
  finish: (job: PushJob, completion: PushCompletion) => Promise<boolean>;
  clearToken: (job: PushJob, token: string) => Promise<boolean>;
  random?: () => number;
  nowSeconds?: () => number;
}

/// Ağ çağrıları enjekte edilir; başarılı FCM sonrası DB hatası asla retry'ye
/// çevrilmez. Ack aynı lease ile yinelenir. Sonraki lease'de olası tekrar,
/// FCM+Postgres arasında dağıtık işlem olmadığı için tamamen önlenemez.
export async function deliverPushJob(
  job: PushJob,
  deps: DeliveryDependencies,
): Promise<PushOutcome | "unsettled"> {
  let completion: PushCompletion = {
    outcome: "skipped",
    errorCode: "no_token",
  };
  const nowSeconds = deps.nowSeconds?.() ?? Math.floor(Date.now() / 1000);
  const expiresAt = validPushExpiry(job.expires_at)
    ? Math.floor(Date.parse(job.expires_at) / 1000)
    : NaN;
  if (!Number.isFinite(expiresAt)) {
    completion = { outcome: "skipped", errorCode: "invalid_expiry" };
  } else if (expiresAt <= nowSeconds) {
    completion = { outcome: "skipped", errorCode: "expired" };
  } else if (job.fcm_token) {
    try {
      const response = await deps.send(
        job,
        job.fcm_token,
        buildFcmMessage(job, job.fcm_token, nowSeconds),
      );
      if (response.ok) {
        completion = { outcome: "sent" };
        try {
          await response.body?.cancel();
        } catch (_) { /* FCM kabul etti */ }
      } else {
        let body: unknown = null;
        try {
          body = await response.json();
        } catch (_) { /* boş gövde */ }
        const delay = retryAfterSeconds(
          response.status,
          body,
          job.attempt_count ?? 1,
          response.headers.get("retry-after"),
          Date.now(),
          deps.random?.() ?? Math.random(),
        );
        completion = delay === null
          ? { outcome: "failed", errorCode: fcmErrorCode(body) }
          : {
            outcome: "retry",
            errorCode: fcmErrorCode(body),
            retryAfterSeconds: delay,
          };
        if (isUnregistered(response.status, body)) {
          try {
            await deps.clearToken(job, job.fcm_token);
          } catch (_) { /* ack yine yazılmalı */ }
        }
      }
    } catch (_) {
      completion = {
        outcome: "retry",
        errorCode: "network_error",
        retryAfterSeconds: retryAfterSeconds(
          503,
          null,
          job.attempt_count ?? 1,
          null,
          Date.now(),
          deps.random?.() ?? Math.random(),
        )!,
      };
    }
  }
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      if (await deps.finish(job, completion) === true) {
        return completion.outcome;
      }
    } catch (_) { /* yalnız ack yeniden denenir, FCM değil */ }
  }
  return "unsettled";
}
