/// Kullanıcının Supabase kimliklerinde Apple var mı? (`identities` yoksa
/// `app_metadata.provider` / `providers` yedek olarak bakılır.)
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
