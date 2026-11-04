// deno test supabase/functions/avatar-sweep/lib_test.ts
import {
  chunk,
  folderNames,
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
