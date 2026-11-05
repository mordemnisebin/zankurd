// Yerel PostgreSQL bekçisi (PGlite bellek DB).
// node tool/test_seri_dondurma_eski_rpc_koruma_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-17_seri_dondurma_eski_rpc_koruma.sql için:
//  - ESKİ KUSUR önce: eski `spend_streak_freeze` mağaza anahtarıyla bulut 2/2 iken
//    de ücret keser (build 45 ve öncesi yolu);
//  - göçten sonra: mağaza anahtarı `freeze_full` döner ve ücret KESİLMEZ; mağaza
//    DIŞI anahtar (bozulma teklifi) eskisi gibi sınırsız tahsil edilir; aynı anahtar
//    tek tahsilat;
//  - bilinen taban dışı gövde göçü DURDURUR; ikinci uygulama no-op; yedek md5 zinciri;
//  - geri alma gövdeyi birebir (md5) taban'a döndürür; yeniden ileri göç çalışır.
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
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  create table profiles(id uuid primary key);
  create table coin_transactions(id bigserial primary key,
    player_id uuid not null references profiles(id), amount integer not null,
    reason text not null, created_at timestamptz not null default now());
  create table player_progress(player_id uuid primary key references profiles(id),
    snapshot jsonb not null, updated_at timestamptz not null default now());
  create table olcek_tur3_yedek(ad text primary key, tanim text not null, alindi timestamptz not null default now());
`);
await db.query('insert into profiles values ($1)', [U(1)]);
await db.query(`insert into coin_transactions(player_id, amount, reason) values ($1, 1000, 'seed')`, [U(1)]);
await db.query(`insert into player_progress(player_id, snapshot, updated_at) values ($1, $2::jsonb, now() - interval '1 minute')`,
  [U(1), JSON.stringify({v: 2, streak: {freezeBase: 0, freezeLedger: {a: [2, 0]}}})]);
await db.exec(read('2026-08-03_streak_freeze_idempotency.sql'));
await db.exec(read('2026-11-16_seri_dondurma_ust_sinir.sql'));
const md5Of = () => val(`select md5(pg_get_functiondef('public.spend_streak_freeze(text)'::regprocedure))`);
const taban = await md5Of();
assert.equal(taban, 'c2160f4e1f8800a055533ebac98ba650', 'göçteki v_taban 2026-08-03 gövdesiyle aynı olmalı');
const bakiye = () => val(`select sum(amount)::int from coin_transactions where player_id=$1`, [U(1)]);
const old = k => db.query(`select public.spend_streak_freeze($1) r`, [k]).then(x => x.rows[0].r);
await as(1);

{
  const r = await old('shop_freeze_eski');
  assert.equal(r.success, true);
  assert.equal(await bakiye(), 950);
  ok('ESKİ KUSUR: eski işlev mağaza anahtarıyla bulut 2/2 iken de tahsil eder');
}

// Bilinen taban dışı gövde göçü durdurur.
await db.exec(`create or replace function public.spend_streak_freeze(p_idempotency_key text) returns jsonb language sql security definer set search_path=public as $$ select '{}'::jsonb $$`);
{
  let durdu = false;
  try { await db.exec(read('2026-11-17_seri_dondurma_eski_rpc_koruma.sql')); } catch (e) {
    durdu = String(e.message).includes('bilinen taban değil');
    if (!durdu) console.log(e.message);
    try { await db.exec('rollback'); } catch (_) { /* açık işlem yok */ }
  }
  assert(durdu);
  ok('bilinen taban dışı gövde göçü durdurur');
}
// Tabanı geri kur (yeniden 08-03 gövdesi).
await db.exec(read('2026-08-03_streak_freeze_idempotency.sql'));
assert.equal(await md5Of(), taban);

await db.exec(read('2026-11-17_seri_dondurma_eski_rpc_koruma.sql'));
const yamali = await md5Of();
assert.notEqual(yamali, taban);
assert.equal(await val(`select count(*)::int from olcek_tur3_yedek where ad='guard_seri:public.spend_streak_freeze(text)'`), 1);
ok('göç: gövde yamalandı, yedek satırı yazıldı');

{
  const r = await old('shop_freeze_yeni');
  assert.equal(r.success, false);
  assert.equal(r.error, 'freeze_full');
  assert.equal(await bakiye(), 950);
  ok('eski işlev artık mağaza anahtarını sınırlar: freeze_full, ücret kesilmedi');
  const offer = await old('result_round_123');
  assert.equal(offer.success, true);
  assert.equal(await bakiye(), 900);
  ok('mağaza DIŞI anahtar (bozulma teklifi) eskisi gibi tahsil edilir');
  const again = await old('result_round_123');
  assert.equal(again.already_charged, true);
  assert.equal(await bakiye(), 900);
  ok('aynı anahtar tek tahsilat');
}
await db.exec(read('2026-11-17_seri_dondurma_eski_rpc_koruma.sql'));
assert.equal(await md5Of(), yamali);
ok('ikinci uygulama no-op');
assert.equal(await val(`select has_function_privilege('anon','public.spend_streak_freeze(text)','execute')`), false);
assert.equal(await val(`select has_function_privilege('authenticated','public.spend_streak_freeze(text)','execute')`), true);
ok('yetkiler korunur');

await db.exec(read('geri_al/2026-11-17_seri_dondurma_eski_rpc_koruma_geri.sql'));
assert.equal(await md5Of(), taban);
assert.equal(await val(`select count(*)::int from olcek_tur3_yedek where ad like 'guard_seri:%'`), 0);
ok('geri alma gövdeyi birebir tabana döndürür');
await db.exec(read('2026-11-17_seri_dondurma_eski_rpc_koruma.sql'));
assert.equal(await md5Of(), yamali);
ok('yeniden ileri göç çalışır');
console.log(`TAMAM: ${n} kontrol`);
