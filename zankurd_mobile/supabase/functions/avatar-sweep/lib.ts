// avatar-sweep yardımcıları — saf işlevler (ağ ve ortam YOK), Deno testiyle
// sınanabilsin diye index.ts'ten ayrıldı. Gizli değer içermez, günlüğe yazmaz.

export const AVATAR_BUCKET = "avatars";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/// Üst klasör adı bir kullanıcı kimliği (uuid) mi? Değilse klasöre ASLA
/// dokunulmaz: bilmediğimiz yerleşim silinmez.
export function isUserFolder(name: string): boolean {
  return UUID_RE.test(name);
}

export interface StorageEntry {
  name: string;
  id?: string | null;
}

/// Kök listeleme sonucundan uuid biçimli klasör adlarını çıkarır (yinelenen
/// ve uuid olmayan adlar atılır, küçük harfe çevrilir).
export function folderNames(entries: StorageEntry[]): string[] {
  const out = new Set<string>();
  for (const e of entries) {
    const name = (e?.name ?? "").toLowerCase();
    if (isUserFolder(name)) out.add(name);
  }
  return [...out];
}

/// Sahipsiz klasörler: kullanıcısı HİÇBİR kaynakta (profiles, auth.users)
/// görünmeyenler. [existing] iki kaynağın birleşimidir; şüphede silinmez.
export function orphanFolders(
  folders: string[],
  existing: Set<string>,
): string[] {
  return folders.filter((f) => !existing.has(f.toLowerCase()));
}

/// Klasör içi nesne adlarını tam nesne yoluna çevirir. Alt klasör satırları
/// (id yok) ve güvensiz adlar ("/", ".." içeren) atlanır.
export function objectPaths(folder: string, entries: StorageEntry[]): string[] {
  const out: string[] = [];
  for (const e of entries) {
    const name = e?.name ?? "";
    if (!name || name.includes("/") || name.includes("..")) continue;
    if (e.id == null) continue;
    out.push(`${folder}/${name}`);
  }
  return out;
}

export function chunk<T>(items: T[], size: number): T[][] {
  if (size < 1) throw new Error("chunk size");
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

export function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
