// avatar-sweep — silinmiş kullanıcıların `avatars` kovasında artakalan
// fotoğraflarını Storage API'siyle siler.
//
// NİÇİN: build 43 ve öncesi istemciler hesap silerken yalnız `delete_my_account`
// RPC'sini çağırır; RPC içindeki `DELETE FROM storage.objects` Supabase'te
// fiziksel dosyayı silmez (yedek yol, hatası yutulur) ve yeni istemcide de Storage
// silme hatası yutulur. Kova HERKESE AÇIK olduğundan silinmiş kullanıcıların
// fotoğrafları adreslenebilir kalırdı. Bu fonksiyon saatlik pg_cron ile çağrılır
// (bkz. supabase/2026-11-08_avatar_supurme.sql) ve güvenilir sunucu tarafı süpürme yapar.
//
// AKIŞ
//   1. `x-cron-secret` başlığı CRON_SECRET'a eşit olmalı (JWT DEĞİL; config.toml'da
//      verify_jwt = false). Yoksa 401.
//   2. Kovanın kökündeki üst klasörler sayfa sayfa listelenir; yalnız uuid biçimli
//      adlar aday olur (başkası ASLA silinmez).
//   3. Bir sayfadaki adaylardan `public.profiles` VEYA `auth.users`'ta (admin API)
//      bulunanlar canlı sayılır; ikisinde de yoksa sahipsizdir. Bir sorgu hata
//      verirse o sayfa ATLANIR (şüphede silme yok).
//   4. Sahipsiz klasörlerin nesneleri 100'lük paketlerle `remove` edilir.
//   Çalıştırma başına en çok MAX_OBJECTS_PER_RUN nesne silinir; kalan sonraki saat.
//
// ORTAM: CRON_SECRET (`supabase secrets set`); SUPABASE_URL ve
// SUPABASE_SERVICE_ROLE_KEY platform tarafından otomatik. Günlüğe yalnız sayılar
// yazılır (kimlik, dosya adı, gizli değer ASLA).

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  AVATAR_BUCKET,
  chunk,
  folderEntries,
  nextSweepOffset,
  objectPaths,
  sanitizeOffset,
  timingSafeEqual,
} from "./lib.ts";

// 2026-11-16 (W4, GPT-6 Pro ALAN 4 #7 #17 #18):
//  - İMLEÇ: `avatar_sweep_state.next_offset` (2026-11-16 göçü) kök listede
//    kaldığımız yeri saklar; her çalıştırma oradan başlar, liste bitince başa
//    döner. Eskiden her saat aynı ilk MAX_FOLDER_PAGES×PAGE_SIZE (20.000)
//    girdi taranıyor, sonrası hiç görülmüyordu. Tablo yoksa (göç uygulanmamış)
//    0'dan başlanır ve uyarı günlüğe yazılır.
//  - KISMİ BAŞARISIZLIK: atlanan sayfa/silinemeyen paket varsa yanıt 500
//    `sweep_partial` (pg_net yanıt tablosunda ve izlemede görünür); eskiden
//    sessizce 200 dönüyordu.
//  - BÜYÜK HARFLİ klasör adları orijinal adlarıyla listelenir/silinir.

const PAGE_SIZE = 100;
const REMOVE_BATCH = 100;
const MAX_OBJECTS_PER_RUN = 1000;
const MAX_FOLDER_PAGES = 200;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function existingUserIds(
  db: SupabaseClient,
  ids: string[],
): Promise<Set<string> | null> {
  const found = new Set<string>();
  const { data, error } = await db.from("profiles").select("id").in("id", ids);
  if (error) return null;
  for (const r of data ?? []) found.add(String(r.id).toLowerCase());
  // Profili olmayan ama auth.users'ta duran hesap da canlıdır.
  for (const id of ids.filter((i) => !found.has(i))) {
    const { data: u, error: e } = await db.auth.admin.getUserById(id);
    if (e && (e as { status?: number }).status !== 404) return null;
    if (u?.user) found.add(id);
  }
  return found;
}

Deno.serve(async (request: Request): Promise<Response> => {
  const expected = Deno.env.get("CRON_SECRET");
  if (!expected) return json({ error: "server_misconfigured" }, 500);
  const presented = request.headers.get("x-cron-secret") ?? "";
  if (!timingSafeEqual(presented, expected)) {
    return json({ error: "unauthorized" }, 401);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "server_misconfigured" }, 500);

  const db = createClient(url, key, { auth: { persistSession: false } });
  const bucket = db.storage.from(AVATAR_BUCKET);
  let scanned = 0, orphans = 0, removed = 0, skippedPages = 0;
  let capped = false;

  // İmleç: kaldığımız kök liste kaydırması (tablo yoksa 0).
  let startOffset = 0;
  let cursorUsable = true;
  {
    const { data, error } = await db.from("avatar_sweep_state")
      .select("next_offset").eq("id", 1).maybeSingle();
    if (error) {
      cursorUsable = false;
      console.error("avatar-sweep: imleç okunamadı (göç uygulanmamış olabilir)", error.code);
    } else {
      startOffset = sanitizeOffset((data as { next_offset?: unknown } | null)?.next_offset);
    }
  }
  let reachedEnd = false;
  let stoppedAt: number | null = null;
  let scannedUntil = startOffset;

  try {
    for (let page = 0; page < MAX_FOLDER_PAGES && !capped; page++) {
      const offset = startOffset + page * PAGE_SIZE;
      const { data: root, error } = await bucket.list("", {
        limit: PAGE_SIZE,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) throw new Error("list_failed");
      if (!root || root.length === 0) {
        reachedEnd = true;
        break;
      }
      const folders = folderEntries(root);
      scanned += folders.length;
      if (folders.length > 0) {
        const existing = await existingUserIds(db, folders.map((f) => f.id));
        if (existing === null) {
          skippedPages++;
        } else {
          for (const folder of folders.filter((f) => !existing.has(f.id))) {
            orphans++;
            // Orijinal ad: büyük harfli klasör küçük harfle listelenemez (#18).
            const { data: files, error: fe } = await bucket.list(folder.name, {
              limit: 1000,
            });
            if (fe) {
              skippedPages++;
              continue;
            }
            for (const batch of chunk(objectPaths(folder.name, files ?? []), REMOVE_BATCH)) {
              if (removed >= MAX_OBJECTS_PER_RUN) {
                capped = true;
                break;
              }
              const { error: re } = await bucket.remove(batch);
              if (re) skippedPages++;
              else removed += batch.length;
            }
            if (capped) break;
          }
        }
      }
      if (capped) {
        stoppedAt = offset;
        break;
      }
      scannedUntil = offset + PAGE_SIZE;
      if (root.length < PAGE_SIZE) {
        reachedEnd = true;
        break;
      }
    }
  } catch (_) {
    console.error("avatar-sweep: hata", { scanned, orphans, removed });
    return json({ error: "sweep_failed", scanned, orphans, removed }, 500);
  }

  const nextOffset = nextSweepOffset({ reachedEnd, stoppedAt, scannedUntil });
  if (cursorUsable) {
    const { error } = await db.from("avatar_sweep_state").upsert({
      id: 1,
      next_offset: nextOffset,
      updated_at: new Date().toISOString(),
    });
    if (error) console.error("avatar-sweep: imleç yazılamadı", error.code);
  }
  const result = { scanned, orphans, removed, skippedPages, capped, startOffset, nextOffset };
  console.log("avatar-sweep", result);
  // Kısmi başarısızlık 200 ile gizlenmez (#17).
  return json(
    skippedPages > 0 ? { error: "sweep_partial", ...result } : result,
    skippedPages > 0 ? 500 : 200,
  );
});

