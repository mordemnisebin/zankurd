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

/// Kök listelemeden uuid biçimli klasörler: `name` Storage'daki ORİJİNAL ad
/// (listeleme/silme bununla yapılır), `id` küçük harfli kullanıcı kimliği
/// (varlık sorgusu bununla yapılır). GPT-6 Pro ALAN 4 #18: eskiden yalnız
/// küçük harfli ad döndüğü için büyük harfli bir klasör `list(küçükHarf)` ile
/// hiç bulunamıyor, sessizce süpürülmeden kalıyordu. Aynı `id`li klasörler
/// (farklı harf büyüklüğü) ayrı ayrı döner: ikisi de süpürülmelidir.
export function folderEntries(
  entries: StorageEntry[],
): Array<{ name: string; id: string }> {
  const seen = new Set<string>();
  const out: Array<{ name: string; id: string }> = [];
  for (const e of entries) {
    const name = e?.name ?? "";
    const id = name.toLowerCase();
    if (!isUserFolder(id) || seen.has(name)) continue;
    seen.add(name);
    out.push({ name, id });
  }
  return out;
}

/// Bir sonraki çalıştırmanın başlayacağı kök sayfa kaydırması (#7: eskiden
/// imleç yoktu, her saat aynı ilk 200×100 girdi taranıyordu).
/// - [reachedEnd]: liste bitti → başa dön;
/// - [stoppedAt]: nesne bütçesi bu sayfada doldu → aynı sayfadan sürdür
///   (silinenler sayfayı küçültür; sayfa yeniden taranır);
/// - aksi hâlde bütçe (sayfa sınırı) bitti → kaldığı yerden.
export function nextSweepOffset(args: {
  reachedEnd: boolean;
  stoppedAt: number | null;
  scannedUntil: number;
}): number {
  if (args.reachedEnd) return 0;
  if (args.stoppedAt !== null) return Math.max(0, args.stoppedAt);
  return Math.max(0, args.scannedUntil);
}

/// Kayıtlı imleç değeri güvenilir mi? (negatif/bozuk → 0)
export function sanitizeOffset(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
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
