// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_idempotency_tur9_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-07_idempotency_tur9.sql için:
//  - aynı çark anahtarı iki kez = tek ödül, ek hak TÜKETİLMEZ (eski yol tüketirdi);
//  - aynı düello isteği iki kez = tek düello (eski yol ikinci düello açardı);
//  - eski çağrılar (anahtarsız) AYNEN çalışır; anahtar/kimlik NULL ise eski yola düşer;
//  - kesin ret (hak yok) kaydedilmez, anahtar sonradan kullanılabilir;
//  - yeni nesneler istemci rollerine kapalı, mevcut işlev gövdeleri değişmez;
//  - beklenmeyen ön durum göçü durdurur; geri alma mevcut gövdeleri birebir bırakır;
//    yeniden ileri göç çalışır.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const ileri = read('2026-11-07_idempotency_tur9.sql');
const geri = read('geri_al/2026-11-07_idempotency_tur9_geri.sql');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const R = n => '70000000-0000-0000-0000-' + String(n).padStart(12, '0');
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

// --- Canlı yüzeyin yerel taklidi: yalnız çağrılan sözleşmeler -----------------
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  create table profiles(id uuid primary key);
  create table coin_transactions(player_id uuid, amount int, reason text);
  create table shop_purchases(player_id uuid, item_id text);
  create table spin_wheel_history(user_id uuid, spin_date date, reward_amount int, unique(user_id, spin_date));
  create function public.award_spin_coins()
  returns table (success boolean, reward_amount integer, message text)
  language plpgsql security definer set search_path = public as $$
  declare v_id uuid;
  begin
    insert into spin_wheel_history values (auth.uid(), current_date, 25)
      on conflict do nothing returning user_id into v_id;
    if v_id is null then return query select false, 0, 'Already spun today'::text; return; end if;
    insert into coin_transactions values (auth.uid(), 25, 'spin_wheel');
    return query select true, 25, 'ok'::text;
  end $$;
  create function public.claim_extra_spin() returns jsonb
  language plpgsql security definer set search_path = public as $$
  declare p int; u int;
  begin
    select count(*) into p from shop_purchases where player_id = auth.uid() and item_id = 'spin_wheel_extra';
    select count(*) into u from coin_transactions where player_id = auth.uid() and reason = 'extra_spin:server';
    if p <= u then return jsonb_build_object('amount', 0, 'no_spins', true); end if;
    insert into coin_transactions values (auth.uid(), 50, 'extra_spin:server');
    return jsonb_build_object('amount', 50, 'no_spins', false);
  end $$;
  create table async_duels(id uuid primary key default gen_random_uuid(), creator uuid, code text, expired boolean default false);
  create function public.start_async_duel(p_category text default null) returns jsonb
  language plpgsql security definer set search_path = public as $$
  declare d uuid;
  begin
    insert into async_duels(creator) values (auth.uid()) returning id into d;
    return jsonb_build_object('duel_id', d, 'role', 'creator', 'category', p_category);
  end $$;
  create function public.create_async_duel_challenge(p_category text default null, p_friend_id uuid default null) returns jsonb
  language plpgsql security definer set search_path = public as $$
  declare d uuid; c text := 'D' || substr(md5(random()::text), 1, 6);
  begin
    insert into async_duels(creator, code) values (auth.uid(), c) returning id into d;
    return jsonb_build_object('duel_id', d, 'role', 'creator', 'challenge_code', c);
  end $$;
  create function public.resume_my_async_duel(p_duel_id uuid) returns jsonb
  language plpgsql security definer set search_path = public as $$
  declare r async_duels%rowtype;
  begin
    select * into r from async_duels where id = p_duel_id and creator = auth.uid();
    if not found then raise exception 'Duel not found'; end if;
    if r.expired then raise exception 'Duel expired'; end if;
    return jsonb_build_object('duel_id', r.id, 'role', 'creator', 'challenge_code', r.code, 'resumed', true);
  end $$;
`);
for (let i = 1; i <= 3; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
  await db.query('insert into profiles values ($1)', [U(i)]);
}
const MEVCUT = ['award_spin_coins()', 'claim_extra_spin()', 'start_async_duel(text)',
  'create_async_duel_challenge(text,uuid)', 'resume_my_async_duel(uuid)'];
const md5ler = async () => {
  const o = {};
  for (const s of MEVCUT) o[s] = await val(`select md5(pg_get_functiondef('public.${s}'::regprocedure))`);
  return o;
};
const oncesi = await md5ler();

// --- Göç öncesi: eski kusurlar --------------------------------------------------
await as(1);
await db.query(`insert into shop_purchases values ($1, 'spin_wheel_extra')`, [U(1)]);
{
  const a = await one('select * from public.award_spin_coins()');
  assert.equal(a.success, true);
  // Yanıt kaybolmuş gibi aynı çağrıyı tekrarla: eski istemci ek hakkı yakar.
  const b = await one('select * from public.award_spin_coins()');
  assert.equal(b.success, false);
  const ek = await val('select public.claim_extra_spin()');
  assert.equal(ek.amount, 50);
  assert.equal(await val(`select count(*)::int from coin_transactions where player_id=$1`, [U(1)]), 2);
  ok('ESKİ KUSUR: yeniden deneme satın alınmış ek hakkı tüketiyor');
}
{
  await db.query(`select public.start_async_duel('x')`);
  await db.query(`select public.start_async_duel('x')`);
  assert.equal(await val(`select count(*)::int from async_duels where creator=$1`, [U(1)]), 2);
  ok('ESKİ KUSUR: yeniden deneme ikinci düello açıyor');
}

// --- Göç ------------------------------------------------------------------------
await db.exec(ileri);
assert.deepEqual(await md5ler(), oncesi);
ok('göç uygulandı; mevcut 5 işlevin gövdesi (md5) AYNI');
await hata(() => db.exec(ileri), 'zaten var');
ok('göç ikinci kez uygulanınca durur (yaratılacak nesneler var)');

// --- 1. Çark ----------------------------------------------------------------------
await as(2);
await db.query(`insert into shop_purchases values ($1, 'spin_wheel_extra')`, [U(2)]);
const sayac = async u => ({
  toplam: await val(`select count(*)::int from coin_transactions where player_id=$1`, [U(u)]),
  ek: await val(`select count(*)::int from coin_transactions where player_id=$1 and reason='extra_spin:server'`, [U(u)]),
});
{
  const a = await val(`select public.spin_wheel_once('anahtar-0001')`);
  assert.deepEqual([a.success, a.amount, a.kind, a.replayed], [true, 25, 'daily', undefined]);
  const b = await val(`select public.spin_wheel_once('anahtar-0001')`);
  assert.deepEqual([b.success, b.amount, b.kind, b.replayed], [true, 25, 'daily', true]);
  assert.deepEqual(await sayac(2), {toplam: 1, ek: 0});
  ok('çark: aynı anahtar iki kez = tek ödül; SATIN ALINMIŞ EK HAK tüketilmedi');
}
{
  const c = await val(`select public.spin_wheel_once('anahtar-0002')`);
  assert.deepEqual([c.success, c.amount, c.kind], [true, 50, 'extra']);
  const d = await val(`select public.spin_wheel_once('anahtar-0002')`);
  assert.deepEqual([d.amount, d.kind, d.replayed], [50, 'extra', true]);
  assert.deepEqual(await sayac(2), {toplam: 2, ek: 1});
  ok('çark: günlük bittikten sonra yeni anahtar tek ek hakkı tüketir; tekrarı tüketmez');
}
{
  const e = await val(`select public.spin_wheel_once('anahtar-0003')`);
  assert.deepEqual([e.success, e.amount, e.kind, e.no_spins], [false, 0, 'none', true]);
  assert.equal(await val(`select count(*)::int from idempotent_ops where user_id=$1`, [U(2)]), 2);
  await db.query(`insert into shop_purchases values ($1, 'spin_wheel_extra')`, [U(2)]);
  const f = await val(`select public.spin_wheel_once('anahtar-0003')`);
  assert.deepEqual([f.success, f.amount, f.kind], [true, 50, 'extra']);
  ok('çark: kesin ret (hak yok) KAYDEDİLMEZ; aynı anahtar sonradan çalışır');
}
{
  const kisa = await val(`select public.spin_wheel_once('abc')`);
  assert.deepEqual([kisa.success, kisa.error], [false, 'invalid key']);
  const bos = await val(`select public.spin_wheel_once(null)`);
  assert.equal(bos.error, 'invalid key');
  await as(null);
  const anonim = await val(`select public.spin_wheel_once('anahtar-0009')`);
  assert.equal(anonim.error, 'not authenticated');
  ok('çark: geçersiz anahtar ve oturumsuz çağrı reddedilir, hiçbir şey yazmaz');
}
{
  // Başka kullanıcı aynı anahtar metnini kullanınca ayrı kayıt.
  await as(3);
  const g = await val(`select public.spin_wheel_once('anahtar-0001')`);
  assert.deepEqual([g.success, g.kind, g.replayed], [true, 'daily', undefined]);
  ok('çark: anahtar kullanıcıya özeldir (aynı metin başka hesapta ayrı işlem)');
}

// --- 2. Düello --------------------------------------------------------------------
await as(1);
{
  const sayi = () => val(`select count(*)::int from async_duels where creator=$1`, [U(1)]);
  const once = await sayi();
  const a = await val(`select public.start_async_duel('x', $1::uuid)`, [R(1)]);
  const b = await val(`select public.start_async_duel('x', $1::uuid)`, [R(1)]);
  assert.equal(a.duel_id, b.duel_id);
  assert.equal(b.resumed, true);
  assert.equal(await sayi(), once + 1);
  const c = await val(`select public.start_async_duel('x', $1::uuid)`, [R(2)]);
  assert.notEqual(c.duel_id, a.duel_id);
  assert.equal(await sayi(), once + 2);
  ok('düello: aynı istek kimliği tek düello; yeni kimlik yeni düello');
}
{
  const a = await val(`select public.create_async_duel_challenge('x', null, $1::uuid)`, [R(3)]);
  const b = await val(`select public.create_async_duel_challenge('x', null, $1::uuid)`, [R(3)]);
  assert.equal(a.duel_id, b.duel_id);
  assert.equal(a.challenge_code, b.challenge_code);
  ok('meydan okuma: aynı istek kimliği aynı düello ve AYNI bağlantı kodu');
}
{
  const a = await val(`select public.start_async_duel('x', $1::uuid)`, [R(4)]);
  await db.query(`update async_duels set expired = true where id = $1`, [a.duel_id]);
  const b = await val(`select public.start_async_duel('x', $1::uuid)`, [R(4)]);
  assert.equal(b.duel_id, a.duel_id);
  assert.equal(b.resumed, undefined);
  ok('düello: devam yolu hata verirse ilk yanıt döner (istemci anlamlı hata alır)');
}
{
  const sayi = () => val(`select count(*)::int from async_duels where creator=$1`, [U(1)]);
  const once = await sayi();
  const kayit = () => val(`select count(*)::int from idempotent_ops where op_key like 'duel:%' and user_id=$1`, [U(1)]);
  const kayitOnce = await kayit();
  const a = await val(`select public.start_async_duel('x', null::uuid)`);
  const eski = await val(`select public.start_async_duel('x')`);
  const eski2 = await val(`select public.create_async_duel_challenge('x', null)`);
  assert(a.duel_id && eski.duel_id && eski2.duel_id);
  assert.equal(await sayi(), once + 3);
  assert.equal(await kayit(), kayitOnce);
  ok('eski (anahtarsız) çağrılar ve NULL kimlik eski gibi çalışır, kayıt tutulmaz');
}
{
  await as(null);
  await hata(() => db.query(`select public.start_async_duel('x', $1::uuid)`, [R(5)]), 'Not authenticated');
  await hata(() => db.query(`select public.create_async_duel_challenge('x', null, $1::uuid)`, [R(5)]), 'Not authenticated');
  ok('düello: oturumsuz çağrı reddedilir');
}

// --- Yetki ve gövde ----------------------------------------------------------------
{
  for (const s of ['spin_wheel_once(text)', 'start_async_duel(text,uuid)', 'create_async_duel_challenge(text,uuid,uuid)']) {
    const r = await one(`select p.prosecdef, p.proconfig, has_function_privilege('anon', p.oid, 'execute') anon,
      has_function_privilege('public', p.oid, 'execute') pub, has_function_privilege('authenticated', p.oid, 'execute') auth
      from pg_proc p where p.oid = 'public.${s}'::regprocedure`);
    assert.equal(r.prosecdef, true);
    assert.deepEqual(r.proconfig, ['search_path=public, pg_temp']);
    assert.deepEqual([r.anon, r.pub, r.auth], [false, false, true]);
  }
  const t = await one(`select has_table_privilege('anon','public.idempotent_ops','select') a,
    has_table_privilege('authenticated','public.idempotent_ops','select,insert,update,delete') b,
    (select relrowsecurity from pg_class where oid='public.idempotent_ops'::regclass) rls`);
  assert.deepEqual([t.a, t.b, t.rls], [false, false, true]);
  ok('yeni işlevler definer/search_path sabit/anon kapalı; kayıt defteri RLS açık ve istemciye kapalı');
}

// --- Beklenmeyen ön durum ----------------------------------------------------------
{
  await db.exec(geri);
  assert.equal(await val(`select to_regclass('public.idempotent_ops')::text`), null);
  assert.equal(await val(`select to_regprocedure('public.spin_wheel_once(text)')::text`), null);
  assert.equal(await val(`select to_regprocedure('public.start_async_duel(text,uuid)')::text`), null);
  assert.equal(await val(`select to_regprocedure('public.create_async_duel_challenge(text,uuid,uuid)')::text`), null);
  assert.deepEqual(await md5ler(), oncesi);
  ok('geri alma: yeni nesneler gitti, mevcut 5 işlevin gövdesi BİREBİR aynı');
  // Eski çağrılar geri almadan sonra da çalışır (build 43).
  await as(1);
  assert((await val(`select public.start_async_duel('x')`)).duel_id);
  ok('geri alma sonrası eski çağrılar çalışır');
}
{
  await db.exec(ileri);
  assert.deepEqual(await md5ler(), oncesi);
  await as(2);
  const a = await val(`select public.spin_wheel_once('anahtar-yeni1')`);
  assert.equal(a.replayed, undefined);
  ok('yeniden ileri göç çalışır');
  await db.exec(geri);
}
{
  await db.exec('drop function public.resume_my_async_duel(uuid)');
  await hata(() => db.exec(ileri), 'beklenen canlı nesneler eksik');
  ok('çağrılan mevcut işlev yoksa göç durur');
}
console.log(`TAMAM: ${n} kontrol`);
