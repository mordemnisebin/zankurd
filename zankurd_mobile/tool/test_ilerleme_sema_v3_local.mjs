// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_ilerleme_sema_v3_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-10_ilerleme_sema_v3.sql için:
//  - ESKİ KUSURLAR göç öncesi gövdelerde GÖSTERİLİR: eski şemalı yazım yeni şemalı
//    kaydı eziyor (v2 ve koşulsuz save_my_progress), boyut reddi istisna;
//  - göçten sonra: v3 daha eski şemayı YAPISAL reddeder, tetikleyici HER yolu
//    (v2, koşulsuz, doğrudan SQL) durdurur, aynı/yeni şemalı yazım geçer;
//  - boyut reddi yapısal (`too_large`), ölçü UTF-8 bayttır (karakter sayısı değil);
//  - mevcut üç işlevin gövdesi (md5) DEĞİŞMEZ; yeni nesneler istemci rollerine kapalı;
//  - beklenmeyen ön durum göçü durdurur; geri alma mevcut gövdeleri birebir bırakır
//    ve tetikleyiciyi kaldırır; yeniden ileri göç çalışır.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const ileri = read('2026-11-10_ilerleme_sema_v3.sql');
const geri = read('geri_al/2026-11-10_ilerleme_sema_v3_geri.sql');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
const val = async (sql, args = []) => Object.values((await one(sql, args)))[0];
const hata = async (fn, parca) => {
  try { await fn(); } catch (e) {
    assert(String(e.message).includes(parca), `hata "${parca}" içermeli: ${e.message}`);
    try { await db.exec('rollback'); } catch (_) { /* açık işlem yok */ }
    return;
  }
  assert.fail(`"${parca}" hatası bekleniyordu`);
};
let n = 0;
const ok = m => console.log('PASS', ++n, m);

// --- Canlı yüzeyin yerel taklidi: gerçek göç dosyalarından kesitler ---------------
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  create table profiles(id uuid primary key);
`);
const esitleme = read('2026-10-15_ilerleme_esitleme.sql');
const kes = (kaynak, bas, son) => {
  const a = kaynak.indexOf(bas);
  const b = kaynak.indexOf(son, a);
  assert(a >= 0 && b > a, `kesit bulunamadı: ${bas}`);
  return kaynak.slice(a, b);
};
// Gerçek tablo + get_my_progress + koşulsuz save_my_progress (2026-10-15).
await db.exec(kes(esitleme, 'create table if not exists public.player_progress', 'revoke all on function public.get_my_progress()'));
await db.exec(`revoke all on function public.get_my_progress() from public, anon;
  grant execute on function public.get_my_progress() to authenticated;
  revoke all on function public.save_my_progress(jsonb) from public, anon;
  grant execute on function public.save_my_progress(jsonb) to authenticated;`);
// Gerçek save_my_progress_v2 (2026-10-26), BEGIN/COMMIT'iyle.
await db.exec(read('2026-10-26_ilerleme_surum_denetimi.sql'));
for (let i = 1; i <= 3; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
  await db.query('insert into profiles values ($1)', [U(i)]);
}
const MEVCUT = ['get_my_progress()', 'save_my_progress(jsonb)', 'save_my_progress_v2(jsonb,timestamptz)'];
const md5ler = async () => {
  const o = {};
  for (const s of MEVCUT) o[s] = await val(`select md5(pg_get_functiondef('public.${s}'::regprocedure))`);
  return o;
};
const oncesi = await md5ler();
const snap = (v, extra = {}) => JSON.stringify({v, xp: 1, ...extra});
const upd = async () => val(`select updated_at from player_progress where player_id=$1`, [U(1)]);
const saklanan = async u => val(`select snapshot from player_progress where player_id=$1`, [U(u)]);

// --- Göç öncesi: ESKİ KUSURLAR -------------------------------------------------------
await as(1);
{
  // v2 şemalı kayıt (seri defteri + kelime silme işaretleri taşıyor).
  await db.query(`select public.save_my_progress_v2($1::jsonb, null)`,
    [snap(2, {streak: {freezeBase: 0}, wordsGone: {a: 5}})]);
  // Eski istemci kaydı okumuş gibi doğru zaman damgasıyla v1 yazar.
  const r = await val(`select public.save_my_progress_v2($1::jsonb, $2)`, [snap(1), await upd()]);
  assert.equal(r.ok, true);
  assert.equal((await saklanan(1)).v, 1);
  assert.equal((await saklanan(1)).wordsGone, undefined);
  ok('ESKİ KUSUR: v2 işlevi daha eski şemalı (v1) yazımın v2 kaydını ezmesini kabul ediyor (defter ve silme işaretleri gitti)');
}
{
  await db.query(`select public.save_my_progress_v2($1::jsonb, $2)`, [snap(2, {wordsGone: {b: 1}}), await upd()]);
  await db.query(`select public.save_my_progress($1::jsonb)`, [snap(1)]);
  assert.equal((await saklanan(1)).v, 1);
  ok('ESKİ KUSUR: koşulsuz save_my_progress da v2 kaydını eziyor');
}
{
  const buyuk = JSON.stringify({v: 1, pad: 'ğ'.repeat(140000)}); // 140.000 karakter, ~280.000 bayt
  await hata(() => db.query(`select public.save_my_progress_v2($1::jsonb, $2)`, [buyuk, null]), 'Snapshot too large');
  ok('ESKİ KUSUR: boyut reddi İSTİSNA (yapısal durum değil; istemci bütün yedeği bırakıyordu)');
}

// --- Göç ----------------------------------------------------------------------------
await db.exec(ileri);
assert.deepEqual(await md5ler(), oncesi);
ok('göç uygulandı; mevcut 3 işlevin gövdesi (md5) AYNI');
await hata(() => db.exec(ileri), 'zaten var');
ok('göç ikinci kez uygulanınca durur (yaratılacak nesneler var)');

// --- Şema sürümü ---------------------------------------------------------------------
{
  const v = async j => val(`select public.progress_snapshot_version($1::jsonb)`, [j]);
  assert.equal(await v('{"v":2}'), 2);
  assert.equal(await v('{"v":1}'), 1);
  assert.equal(await v('{}'), 0);
  assert.equal(await v('{"v":"2"}'), 0);
  assert.equal(await v('{"v":-5}'), 0);
  assert.equal(await v('{"v":1000000000}'), 1000);
  assert.equal(await v('{"v":2.9}'), 2);
  ok('progress_snapshot_version: yok/sayı değil = 0, negatif = 0, üst sınır 1000, kesirli aşağı');
}
await as(1);
{
  // v2 kaydını yeniden kur.
  const g = await val(`select public.save_my_progress_v3($1::jsonb, $2)`, [snap(2, {wordsGone: {c: 3}}), await upd()]);
  assert.equal(g.ok, true);
  assert.equal((await saklanan(1)).v, 2);
  ok('v3: aynı/yeni şemalı yazım geçer');
}
{
  const r = await val(`select public.save_my_progress_v3($1::jsonb, $2)`, [snap(1), await upd()]);
  assert.equal(r.ok, false);
  assert.equal(r.stale_schema, true);
  assert.equal(r.stored_version, 2);
  assert.equal((await saklanan(1)).wordsGone.c, 3);
  ok('v3: daha eski şemalı yazım YAPISAL reddedilir (stale_schema), kayıt değişmez');
}
{
  // Eski istemcinin v2 işlevi (build 45 ve öncesi) doğru zaman damgasıyla bile ezemez.
  const t = await upd();
  await hata(() => db.query(`select public.save_my_progress_v2($1::jsonb, $2)`, [snap(1), t]),
    'older than the stored one');
  assert.equal((await saklanan(1)).v, 2);
  ok('tetikleyici: eski save_my_progress_v2 ile daha eski şema yazımı DURDURULUR');
}
{
  await hata(() => db.query(`select public.save_my_progress($1::jsonb)`, [snap(1)]),
    'older than the stored one');
  await hata(() => db.query(`select public.save_my_progress($1::jsonb)`, ['{"xp":1}']),
    'older than the stored one');
  assert.equal((await saklanan(1)).v, 2);
  ok('tetikleyici: koşulsuz save_my_progress (v1 ya da sürümsüz) de durdurulur');
}
{
  await hata(() => db.query(`update player_progress set snapshot = $1::jsonb where player_id = $2`, [snap(1), U(1)]),
    'older than the stored one');
  ok('tetikleyici: doğrudan SQL güncellemesi de durdurulur (arka kapı yok)');
}
{
  // Geriye uyum: eski işlevler aynı/yeni şemada AYNEN çalışır.
  const t = await upd();
  const a = await val(`select public.save_my_progress_v2($1::jsonb, $2)`, [snap(2, {xp: 9}), t]);
  assert.equal(a.ok, true);
  const b = await val(`select public.save_my_progress_v2($1::jsonb, $2)`, [snap(2), t]);
  assert.equal(b.conflict, true); // sürüm denetimi (iyimser eşzamanlılık) eskisi gibi
  await db.query(`select public.save_my_progress($1::jsonb)`, [snap(2)]);
  const g = await val(`select public.get_my_progress()`);
  assert.equal(g.snapshot.v, 2);
  ok('eski işlevler (v2, koşulsuz, get) aynı/yeni şemada AYNEN çalışır; çakışma denetimi korunur');
}
{
  // Yeni kullanıcı: ilk yazım (satır yok) v1'den de v2'den de geçer; sonra yalnız yukarı.
  await as(2);
  assert.equal((await val(`select public.save_my_progress_v3($1::jsonb, null)`, [snap(1)])).ok, true);
  const t = await val(`select updated_at from player_progress where player_id=$1`, [U(2)]);
  assert.equal((await val(`select public.save_my_progress_v3($1::jsonb, $2)`, [snap(2), t])).ok, true);
  ok('v3: ilk yazım ve v1 -> v2 yükseltmesi geçer');
}
{
  // Çakışma (zaman damgası) eskisi gibi.
  const r = await val(`select public.save_my_progress_v3($1::jsonb, $2)`, [snap(2), '2000-01-01T00:00:00Z']);
  assert.equal(r.conflict, true);
  assert.equal(r.ok, false);
  const y = await val(`select public.save_my_progress_v3($1::jsonb, null)`, [snap(2)]);
  assert.equal(y.conflict, true);
  ok('v3: sürüm (updated_at) çakışması ve beklenen zamansız yazım reddedilir');
}

// --- Boyut sözleşmesi ------------------------------------------------------------------
await as(3);
{
  const taban = await val(`select octet_length(('{"v": 2, "pad": ""}')::jsonb::text)`);
  const sinir = 262144;
  const doldur = k => JSON.stringify({v: 2, pad: 'x'.repeat(k)});
  const tam = await val(`select public.save_my_progress_v3($1::jsonb, null)`, [doldur(sinir - taban)]);
  assert.equal(tam.ok, true);
  const t = await val(`select updated_at from player_progress where player_id=$1`, [U(3)]);
  const bir = await val(`select public.save_my_progress_v3($1::jsonb, $2)`, [doldur(sinir - taban + 1), t]);
  assert.deepEqual([bir.ok, bir.too_large, bir.bytes, bir.limit], [false, true, sinir + 1, sinir]);
  ok('v3: tam sınırdaki görüntü geçer, bir bayt fazlası YAPISAL too_large (bayt sayısıyla)');
}
{
  // Çok baytlı karakter: 140.000 karakter = ~280.000 bayt. İstemcinin
  // `jsonEncode(...).length` ölçüsü sığar dediği yerde sunucu bayt sayar.
  const t = await val(`select updated_at from player_progress where player_id=$1`, [U(3)]);
  const r = await val(`select public.save_my_progress_v3($1::jsonb, $2)`,
    [JSON.stringify({v: 2, pad: 'ğ'.repeat(140000)}), t]);
  assert.equal(r.too_large, true);
  assert(r.bytes > 262144 && 140000 < 262144);
  ok('v3: ölçü UTF-8 bayttır (karakter sayısı sınırın altında olsa da çok baytlı metin reddedilir)');
}
{
  await as(null);
  await hata(() => db.query(`select public.save_my_progress_v3($1::jsonb, null)`, [snap(2)]), 'Not authenticated');
  await as(1);
  await hata(() => db.query(`select public.save_my_progress_v3('[1]'::jsonb, null)`), 'Invalid snapshot');
  await hata(() => db.query(`select public.save_my_progress_v3(null, null)`), 'Invalid snapshot');
  await db.query(`insert into auth.users values ($1)`, [U(9)]);
  await as(9);
  await hata(() => db.query(`select public.save_my_progress_v3($1::jsonb, null)`, [snap(2)]), 'Profile missing');
  ok('v3: oturumsuz, geçersiz görüntü ve profilsiz çağrı reddedilir');
}

// --- Yetki ve gövde ---------------------------------------------------------------------
{
  const r = await one(`select p.prosecdef, p.proconfig, has_function_privilege('anon', p.oid, 'execute') anon,
    has_function_privilege('public', p.oid, 'execute') pub, has_function_privilege('authenticated', p.oid, 'execute') auth
    from pg_proc p where p.oid = 'public.save_my_progress_v3(jsonb,timestamptz)'::regprocedure`);
  assert.equal(r.prosecdef, true);
  assert.deepEqual(r.proconfig, ['search_path=public, pg_temp']);
  assert.deepEqual([r.anon, r.pub, r.auth], [false, false, true]);
  for (const s of ['progress_snapshot_version(jsonb)', 'player_progress_schema_guard()']) {
    const h = await one(`select has_function_privilege('anon', p.oid, 'execute') anon,
      has_function_privilege('public', p.oid, 'execute') pub, has_function_privilege('authenticated', p.oid, 'execute') auth,
      p.proconfig from pg_proc p where p.oid = 'public.${s}'::regprocedure`);
    assert.deepEqual([h.anon, h.pub, h.auth], [false, false, false]);
    assert.deepEqual(h.proconfig, ['search_path=public, pg_temp']);
  }
  const t = await one(`select has_table_privilege('anon','public.player_progress','select,insert,update,delete') a,
    has_table_privilege('authenticated','public.player_progress','select,insert,update,delete') b`);
  assert.deepEqual([t.a, t.b], [false, false]);
  assert.deepEqual(await md5ler(), oncesi);
  ok('v3 definer/search_path sabit/anon kapalı; yardımcı ve tetikleyici işlevi istemciye kapalı; tablo kapalı; mevcut gövdeler aynı');
}

// --- Geri alma ve ön durum --------------------------------------------------------------
{
  await db.exec(geri);
  for (const s of ['save_my_progress_v3(jsonb,timestamptz)', 'player_progress_schema_guard()', 'progress_snapshot_version(jsonb)']) {
    assert.equal(await val(`select to_regprocedure('public.${s}')::text`), null);
  }
  assert.equal(await val(`select count(*)::int from pg_trigger where tgname='player_progress_schema_guard'`), 0);
  assert.deepEqual(await md5ler(), oncesi);
  ok('geri alma: yeni nesneler ve tetikleyici gitti, mevcut 3 işlevin gövdesi BİREBİR aynı');
  await as(1);
  const sakli = (await saklanan(1)).v;
  assert.equal(sakli, 2);
  await db.query(`select public.save_my_progress($1::jsonb)`, [snap(1)]);
  assert.equal((await saklanan(1)).v, 1);
  ok('geri alma sonrası eski davranış (eski şema ezebilir) döner; kayıtlar silinmedi');
}
{
  await db.exec(ileri);
  assert.deepEqual(await md5ler(), oncesi);
  await as(1);
  await db.query(`select public.save_my_progress($1::jsonb)`, [snap(2)]);
  await hata(() => db.query(`select public.save_my_progress($1::jsonb)`, [snap(1)]), 'older than the stored one');
  ok('yeniden ileri göç çalışır ve koruma geri gelir');
  await db.exec(geri);
}
{
  await db.exec('drop function public.save_my_progress_v2(jsonb, timestamptz)');
  await hata(() => db.exec(ileri), 'beklenen canlı nesneler eksik');
  ok('mevcut işlev yoksa göç durur');
}
console.log(`TAMAM: ${n} kontrol`);
