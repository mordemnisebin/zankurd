// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_seri_dondurma_ust_sinir_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-16_seri_dondurma_ust_sinir.sql için:
//  - ESKİ KUSUR göç öncesi gösterilir: `spend_streak_freeze` jeton bulutta
//    zaten dolu olsa da (2/2) 50 jeton daha keser (iki cihaz / iki ücret);
//  - göçten sonra `spend_streak_freeze_capped`: dolu bulutta ÜCRET KESMEDEN
//    freeze_full; eşitlenmemiş alım sayılır (iki alım -> üçüncü reddedilir);
//    aynı anahtar tek tahsilat (already_charged); bakiye yetersizse ret;
//    eski işlevin gövdesi (md5) DEĞİŞMEZ; yeni işlev anon/PUBLIC'e kapalı;
//    beklenmeyen ön durum göçü durdurur; geri alma yalnız yeni işlevi kaldırır.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const val = async (sql, args = []) => Object.values((await db.query(sql, args)).rows[0])[0];
let n = 0;
const ok = m => console.log('PASS', ++n, m);

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  create table profiles(id uuid primary key);
  create table coin_transactions(
    id bigserial primary key,
    player_id uuid not null references profiles(id),
    amount integer not null,
    reason text not null,
    created_at timestamptz not null default now());
  create table player_progress(
    player_id uuid primary key references profiles(id),
    snapshot jsonb not null,
    updated_at timestamptz not null default now());
`);
for (let i = 1; i <= 4; i++) {
  await db.query('insert into profiles values ($1)', [U(i)]);
  await db.query(`insert into coin_transactions(player_id, amount, reason) values ($1, 1000, 'seed')`, [U(i)]);
}
// Gerçek (canlıdaki) idempotent işlev.
await db.exec(read('2026-08-03_streak_freeze_idempotency.sql'));
const eskiMd5 = await val(`select md5(pg_get_functiondef('public.spend_streak_freeze(text)'::regprocedure))`);
const kaydet = (u, streak, atSql = 'now()') => db.query(
  `insert into player_progress(player_id, snapshot, updated_at) values ($1, $2::jsonb, ${atSql})
   on conflict (player_id) do update set snapshot = excluded.snapshot, updated_at = excluded.updated_at`,
  [U(u), JSON.stringify({v: 2, streak})]);
const bakiye = u => val(`select sum(amount)::int from coin_transactions where player_id=$1`, [U(u)]);

// --- Göç öncesi: ESKİ KUSUR ---------------------------------------------------------
await as(1);
await kaydet(1, {freezeBase: 0, freezeLedger: {a: [2, 0]}}, `now() - interval '1 minute'`);
{
  const r = (await db.query(`select public.spend_streak_freeze('shop_freeze_old') r`)).rows[0].r;
  assert.equal(r.success, true, 'eski işlev bulutta 2/2 iken de tahsil eder');
  assert.equal(await bakiye(1), 950);
  ok('ESKİ KUSUR: bulutta 2/2 iken spend_streak_freeze 50 jeton keser (iki ücret / tek hak)');
}

// --- Göç ---------------------------------------------------------------------------
await db.exec(read('2026-11-16_seri_dondurma_ust_sinir.sql'));
assert.equal(await val(`select md5(pg_get_functiondef('public.spend_streak_freeze(text)'::regprocedure))`), eskiMd5);
ok('göç: spend_streak_freeze gövdesi (md5) değişmedi');
const cap = (k) => db.query(`select public.spend_streak_freeze_capped($1) r`, [k]).then(x => x.rows[0].r);

// Bulut dolu (2): ücret KESİLMEZ.
await as(2);
await kaydet(2, {freezeBase: 0, freezeLedger: {a: [2, 0]}}, `now() - interval '1 minute'`);
{
  const r = await cap('shop_freeze_k1');
  assert.equal(r.success, false);
  assert.equal(r.error, 'freeze_full');
  assert.equal(await bakiye(2), 1000);
  ok('bulutta 2/2 -> freeze_full, ücret kesilmedi');
}
// Eski (mutlak sayı) biçim de okunur.
await as(3);
await kaydet(3, {freeze: 2}, `now() - interval '1 minute'`);
assert.equal((await cap('shop_freeze_k2')).error, 'freeze_full');
ok('defter öncesi mutlak freeze=2 de dolu sayılır');

// Harcanmış jeton yer açar: base 0, gained 2, spent 1 -> 1 tutuluyor.
await as(4);
await kaydet(4, {freezeBase: 0, freezeLedger: {a: [2, 1]}}, `now() - interval '1 minute'`);
{
  const r = await cap('shop_freeze_a');
  assert.equal(r.success, true);
  assert.equal(r.already_charged, false);
  assert.equal(await bakiye(4), 950);
  ok('1/2 iken alım geçer ve 50 jeton keser');
  // Aynı anahtar: tek tahsilat.
  const again = await cap('shop_freeze_a');
  assert.equal(again.success, true);
  assert.equal(again.already_charged, true);
  assert.equal(await bakiye(4), 950);
  ok('aynı anahtar ikinci kez ücret kesmez (already_charged)');
  // Eşitlenmemiş alım sayılır: bulut 1 + eşitlenmemiş 1 = 2 -> ikinci anahtar reddedilir.
  const second = await cap('shop_freeze_b');
  assert.equal(second.error, 'freeze_full');
  assert.equal(second.unsynced, 1);
  assert.equal(await bakiye(4), 950);
  ok('eşitlenmemiş alım sayılır: ikinci cihazın alımı ücret kesilmeden reddedilir');
  // Anlık görüntü yenilenince (hak teslim edilip kaydedildi: 2/2) yine dolu.
  await kaydet(4, {freezeBase: 0, freezeLedger: {a: [3, 1]}});
  assert.equal((await cap('shop_freeze_c')).error, 'freeze_full');
  // Jeton harcandı ve kaydedildi: yeniden yer var.
  await kaydet(4, {freezeBase: 0, freezeLedger: {a: [3, 3]}}, `now() + interval '1 second'`);
  assert.equal((await cap('shop_freeze_d')).success, true);
  ok('anlık görüntü yenilenince sayım yeniden kurulur; harcanan jeton yer açar');
}
// Bakiye yetersiz.
await as(1);
await db.query(`delete from coin_transactions where player_id=$1`, [U(1)]);
await db.query(`insert into coin_transactions(player_id, amount, reason) values ($1, 10, 'seed')`, [U(1)]);
await kaydet(1, {freezeBase: 0});
{
  const r = await cap('shop_freeze_poor');
  assert.equal(r.success, false);
  assert.equal(r.error, 'insufficient balance');
  ok('bakiye yetersizse ret');
}
// Anlık görüntü hiç yoksa: sınır yalnız eşitlenmemiş alımlarla işler.
await db.query(`insert into profiles values ($1)`, [U(9)]);
await db.query(`insert into coin_transactions(player_id, amount, reason) values ($1, 1000, 'seed')`, [U(9)]);
await as(9);
assert.equal((await cap('shop_freeze_n1')).success, true);
assert.equal((await cap('shop_freeze_n2')).success, true);
assert.equal((await cap('shop_freeze_n3')).error, 'freeze_full');
ok('anlık görüntü yokken de en çok 2 alım geçer');
// Girişsiz çağrı.
await as(null);
assert.equal((await cap('shop_freeze_x')).error, 'not authenticated');
ok('oturumsuz çağrı reddedilir');

// Yetkiler.
assert.equal(await val(`select has_function_privilege('anon','public.spend_streak_freeze_capped(text)','execute')`), false);
assert.equal(await val(`select has_function_privilege('authenticated','public.spend_streak_freeze_capped(text)','execute')`), true);
ok('yeni işlev anon/PUBLIC kapalı, authenticated açık');

// Tekrar uygulama durur.
let durdu = false;
try { await db.exec(read('2026-11-16_seri_dondurma_ust_sinir.sql')); } catch (e) {
  durdu = String(e.message).includes('zaten var');
  try { await db.exec('rollback'); } catch (_) { /* açık işlem yok */ }
}
assert(durdu);
ok('yaratılacak işlev varsa göç durur');

// Geri alma.
await db.exec(read('geri_al/2026-11-16_seri_dondurma_ust_sinir_geri.sql'));
assert.equal(await val(`select to_regprocedure('public.spend_streak_freeze_capped(text)') is null`), true);
assert.equal(await val(`select md5(pg_get_functiondef('public.spend_streak_freeze(text)'::regprocedure))`), eskiMd5);
ok('geri alma yalnız yeni işlevi kaldırır');
await db.exec(read('2026-11-16_seri_dondurma_ust_sinir.sql'));
ok('yeniden ileri göç çalışır');
console.log(`TAMAM: ${n} kontrol`);
