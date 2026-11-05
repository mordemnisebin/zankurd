// deno test supabase/functions/avatar-sweep/lib_test.ts
import {
  chunk,
  folderEntries,
  folderNames,
  nextSweepOffset,
  sanitizeOffset,
  isUserFolder,
  objectPaths,
  orphanFolders,
  timingSafeEqual,
} from "./lib.ts";

function assert(cond: unknown, message: string): asserts cond {
  if (!cond) throw new Error(message);
}

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";

Deno.test("yalnız uuid biçimli klasör adları süpürme adayıdır", () => {
  assert(isUserFolder(A), "uuid kabul");
  assert(!isUserFolder("avatars"), "düz ad reddedilir");
  assert(!isUserFolder(`${A}/x`), "yol reddedilir");
  assert(!isUserFolder(""), "boş reddedilir");
  const names = folderNames([
    { name: A, id: null },
    { name: A.toUpperCase(), id: null },
    { name: "readme.txt", id: "x" },
    { name: B },
  ]);
  assert(names.length === 2 && names.includes(A) && names.includes(B), "tekil+uuid");
});

Deno.test("kullanıcısı hâlâ var olan klasör ASLA sahipsiz sayılmaz", () => {
  const orphans = orphanFolders([A, B], new Set([A]));
  assert(orphans.length === 1 && orphans[0] === B, "yalnız B sahipsiz");
  assert(orphanFolders([A, B], new Set([A, B])).length === 0, "hepsi canlı");
  assert(orphanFolders([A], new Set([A.toUpperCase().toLowerCase()])).length === 0, "büyük/küçük harf");
});

Deno.test("nesne yolları klasör önekli; alt klasör ve güvensiz adlar atlanır", () => {
  const paths = objectPaths(B, [
    { name: "avatar.jpg", id: "1" },
    { name: "avatar-17.png", id: "2" },
    { name: "alt", id: null },
    { name: "../x", id: "3" },
    { name: "a/b", id: "4" },
  ]);
  assert(paths.length === 2, "iki geçerli nesne");
  assert(paths.every((p) => p.startsWith(`${B}/`)), "önek");
});

Deno.test("chunk paketleri sınırlar; timingSafeEqual sırrı karşılaştırır", () => {
  const parts = chunk([1, 2, 3, 4, 5], 2);
  assert(parts.length === 3 && parts[2].length === 1, "3 paket");
  assert(timingSafeEqual("s", "s") && !timingSafeEqual("s", "t") && !timingSafeEqual("s", ""), "sır");
});

// ── 2026-11-16 (W4, GPT-6 Pro ALAN 4 #7 #18) ────────────────────────────────
// #18 kusuru: folderNames adı küçük harfe çevirip döndürüyordu; Storage'da
// BÜYÜK harfle duran klasör `list(küçükHarf)` ile bulunamıyor, sessizce hiç
// süpürülmüyordu. folderEntries orijinal adı korur, varlık sorgusu için ayrı
// küçük harfli kimlik verir.
Deno.test("büyük harfli klasör orijinal adıyla listelenir, kimliği küçük harfli", () => {
  const L = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
  const entries = folderEntries([{ name: L.toUpperCase() }, { name: L }, { name: "x.txt" }]);
  assert(entries.length === 2, "iki ayrı klasör adı (ikisi de süpürülmeli)");
  const upper = entries.find((e) => e.name === L.toUpperCase());
  assert(upper !== undefined && upper.id === L, "orijinal ad + küçük harfli id");
  assert(folderNames([{ name: L.toUpperCase() }])[0] === L, "eski API değişmedi");
});

// #7 kusuru: imleç yoktu; her saat aynı ilk 20.000 girdi taranıyordu.
Deno.test("süpürme imleci: kaldığı yerden sürer, bitince başa döner", () => {
  assert(nextSweepOffset({ reachedEnd: true, stoppedAt: null, scannedUntil: 500 }) === 0, "bitti → başa");
  assert(nextSweepOffset({ reachedEnd: false, stoppedAt: null, scannedUntil: 20000 }) === 20000, "sayfa bütçesi → kaldığı yer");
  assert(nextSweepOffset({ reachedEnd: false, stoppedAt: 300, scannedUntil: 400 }) === 300, "nesne bütçesi → aynı sayfa");
  assert(sanitizeOffset(-5) === 0 && sanitizeOffset("7") === 0 && sanitizeOffset(null) === 0, "bozuk imleç 0");
  assert(sanitizeOffset(1200) === 1200, "geçerli imleç");
});
