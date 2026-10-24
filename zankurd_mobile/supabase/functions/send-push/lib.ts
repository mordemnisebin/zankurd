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
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
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
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(signingInput)),
  );
  return `${signingInput}.${base64UrlEncode(signature)}`;
}

/// `tool/send_push_outbox.py` ile AYNI ileti: `notification{title, body}` ve
/// boş olmayan `kind` dizesi varsa `data{kind}` (FCM v1 `data` değerleri dize
/// olmak zorunda; istemci yönlendirmesi lib/src/services/push_tap_router.dart).
export function buildFcmMessage(job: PushJob, token: string) {
  const message: Record<string, unknown> = {
    token,
    notification: {
      title: job.title || "ZanKurd",
      body: job.body || "",
    },
  };
  if (typeof job.kind === "string" && job.kind.length > 0) {
    message.data = { kind: job.kind };
  }
  return { message };
}

/// FCM hata gövdesi + HTTP durumu → jeton kalıcı olarak geçersiz mi?
/// 404 / NOT_FOUND / UNREGISTERED: cihaz uygulamayı silmiş ya da jeton dönmüş;
/// `profiles.fcm_token` temizlenir. INVALID_ARGUMENT bilerek DEĞİL: yük hatası
/// da olabilir, jetonu yanlışlıkla silmeyelim.
export function isUnregistered(status: number, body: unknown): boolean {
  if (status === 404) return true;
  const error = (body as { error?: { status?: string; details?: unknown } } | null)
    ?.error;
  if (!error) return false;
  if (error.status === "NOT_FOUND") return true;
  if (Array.isArray(error.details)) {
    for (const detail of error.details) {
      if ((detail as { errorCode?: string })?.errorCode === "UNREGISTERED") {
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
