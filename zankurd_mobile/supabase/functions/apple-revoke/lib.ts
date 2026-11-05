/// Kullanıcının Supabase kimliklerinde Apple var mı? (`identities` yoksa
/// `app_metadata.provider` / `providers` yedek olarak bakılır.)
///
/// İstemci (`userHasAppleIdentity`, apple_revocation.dart) AYNI ölçütü
/// uygular (GPT-6 Pro ALAN 4 #20: iki taraf farklı ölçüt kullanıyordu).
export function hasAppleIdentity(user: {
  identities?: Array<{ provider?: string }> | null;
  app_metadata?: { provider?: string; providers?: string[] } | null;
}): boolean {
  if (user.identities?.some((i) => i.provider === "apple")) return true;
  const meta = user.app_metadata;
  return meta?.provider === "apple" ||
    (Array.isArray(meta?.providers) && meta.providers.includes("apple"));
}

/// Son kayıt bu kadar saniye içindeyse yeni kayıt Apple'a gitmez.
export const REGISTER_COALESCE_SECONDS = 30;

export function registerRecentlyDone(
  updatedAt: unknown,
  nowMs: number,
): boolean {
  if (typeof updatedAt !== "string") return false;
  const t = Date.parse(updatedAt);
  return Number.isFinite(t) && nowMs - t >= 0 &&
    nowMs - t < REGISTER_COALESCE_SECONDS * 1000;
}

/// Apple'ın `/auth/token` yanıtındaki `id_token`ın yükünü okur. Jeton Apple'dan
/// doğrudan TLS üzerinden alındığı için imza yeniden doğrulanmaz; yalnız `sub`
/// (Apple kullanıcı kimliği) karşılaştırılır. Bozuk jeton `null` döner.
export function decodeJwtPayload(jwt: unknown): Record<string, unknown> | null {
  if (typeof jwt !== "string") return null;
  const parts = jwt.split(".");
  if (parts.length < 2 || !parts[1]) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    const parsed = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(atob(padded), (c) => c.charCodeAt(0)),
      ),
    );
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch (_) {
    return null;
  }
}

/// Supabase kullanıcısının Apple kimliğindeki Apple `sub`ı (GPT-6 Pro ALAN 4
/// #16): `identity_data.sub`, yoksa `provider_id`. Yoksa `null`.
export function appleSubjectOf(user: {
  identities?: Array<
    {
      provider?: string;
      provider_id?: string;
      identity_data?: Record<string, unknown> | null;
    }
  > | null;
}): string | null {
  for (const identity of user.identities ?? []) {
    if (identity.provider !== "apple") continue;
    const sub = identity.identity_data?.sub;
    if (typeof sub === "string" && sub.length > 0) return sub;
    if (typeof identity.provider_id === "string" && identity.provider_id) {
      return identity.provider_id;
    }
  }
  return null;
}

/// Takas edilen kodun sahibi (id_token.sub) oturumdaki kullanıcının Apple
/// hesabı mı? Taraflardan biri eksikse `false` (kapalı başarısızlık): başka
/// bir Apple hesabının kodu bu kullanıcının altında saklanıp yanlış hesap
/// iptal edilmesin.
export function appleSubjectMatches(
  idToken: unknown,
  expectedSub: string | null,
): boolean {
  if (!expectedSub) return false;
  const sub = decodeJwtPayload(idToken)?.sub;
  return typeof sub === "string" && sub.length > 0 && sub === expectedSub;
}

/// `/auth/revoke` sonucu: 200 (iptal) ya da `invalid_grant` (jeton zaten
/// geçersiz) amaca ulaşmıştır; başka her şey yeniden denenir.
export function revokeOutcome(
  status: number,
  error: unknown,
): "revoked" | "failed" {
  return status === 200 || (status === 400 && error === "invalid_grant")
    ? "revoked"
    : "failed";
}

/// Zamanlama saldırısına dayanıklı dize karşılaştırması (cron sırrı için).
export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
