// Yerel PostgreSQL bekçisi (W10): ağ/üretim bağlantısı yok; PGlite bellek DB.
// node tool/test_rekabet_sunucu_havuzu_local.mjs /absolute/path/to/pglite/dist/index.js
//
// 2026-11-17_rekabet_sunucu_havuzu.sql (rekabetçi modlar için sunucu-yalnız soru havuzu).
// Canlıdaki altı işlevin gövdesi göç dosyalarındaki GERÇEK metinlerden kurulur
// (weighted_question_pick: 10-18, async_duel_questions_payload: 10-13,
// present_async_duel_question_v2: room_duel_guards, W2 işlevleri: rekabet_sunum.sql);
// göçteki taban md5 sabitleri bu zincirden yeniden hesaplanıp karşılaştırılır.
// W10_PRINT=1: taban + nihai md5'leri yazdırıp çıkar (göçteki sabitler için).
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const md5 = t => crypto.createHash('md5').update(t).digest('hex');
const q = async (sql, args = []) => (await db.query(sql, args)).rows;
const one = async (sql, args = []) => (await q(sql, args))[0];
const call = async (sql, args = []) => (await one(`select ${sql} r`, args)).r;
const defOf = async sig => (await one(`select pg_get_functiondef('${sig}'::regprocedure) d`)).d;
const kapat = async () => { try { await db.exec('rollback'); } catch (e) { /* açık işlem yok */ } };
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create (?:or replace )?function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1).replace(/^create function/i, 'create or replace function');
};
const SIG = {
  pick: 'public.weighted_question_pick(uuid[],uuid[],integer)',
  payload: 'public.async_duel_questions_payload(uuid[])',
  duelPresent: 'public.present_async_duel_question_v2(uuid,integer)',
  dailySet: 'public._w2_daily_set(date)',
  dailyPresent: 'public.present_verified_daily_question(uuid,integer)',
  roomV2: 'public.get_room_questions_v2(uuid)',
};
const ORDER = ['pick', 'payload', 'duelPresent', 'dailySet', 'dailyPresent', 'roomV2'];
let forward = read('2026-11-17_rekabet_sunucu_havuzu.sql');
const geri = read('geri_al/2026-11-17_rekabet_sunucu_havuzu_geri.sql');

const me = '10000000-0000-0000-0000-000000000001';
const catZ = '20000000-0000-0000-0000-000000000001'; // Ziman: sunucu-yalnız soru yok
const catA = '20000000-0000-0000-0000-000000000002'; // Cografya: bol sunucu-yalnız
const catB = '20000000-0000-0000-0000-000000000003'; // Dîrok: az sunucu-yalnız (< 30)
const qid = (c, i) => `30${c}00000-0000-0000-0000-${String(i).padStart(12, '0')}`;
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create function public.app_today() returns date language sql stable as $$select current_date$$;
create table profiles(id uuid primary key);
insert into auth.users values('${me}'); insert into profiles values('${me}');
create table categories(id uuid primary key, name text, is_active boolean default true);
insert into categories values('${catZ}','Ziman',true),('${catA}','Cografya',true),('${catB}','Dîrok',true);
create table questions(id uuid primary key, category_id uuid, prompt text, option_a text, option_b text, option_c text, option_d text,
  question_type text, image_url text, difficulty integer default 2, correct_option text, is_approved boolean default true,
  explanation text, explanation_ku text, explanation_tr text);
create table app_runtime_config(id smallint primary key default 1, min_supported_build_ios integer not null default 0,
  updated_at timestamptz not null default now());
insert into app_runtime_config(id) values (1);
create table olcek_tur3_yedek(ad text primary key, tanim text not null, alindi timestamptz not null default now());
alter table olcek_tur3_yedek enable row level security;
revoke all on olcek_tur3_yedek from public, anon, authenticated;
create table async_duels(id uuid primary key, question_ids uuid[]);
`);
// Sorular: Ziman 40 yerel; Cografya 40 yerel + 40 sunucu-yalnız (sonradan işaretlenir); Dîrok 40 yerel + 5 sunucu-yalnız.
const ins = async (cat, c, from, to, label) => {
  for (let i = from; i <= to; i++)
    await db.exec(`insert into questions(id,category_id,prompt,option_a,option_b,option_c,option_d,question_type,correct_option,difficulty)
      values('${qid(c, i)}','${cat}','${label} ${i}','a','b','c','d','multiple_choice','A',${1 + (i % 4)})`);
};
await ins(catZ, 1, 1, 40, 'ZIMAN');
await ins(catA, 2, 1, 80, 'COG');
await ins(catB, 3, 1, 45, 'DIR');
// Gerçek göç zinciri (yalnız bu işlevler için): taban gövdeleri.
const ys = read('2026-10-18_oda_kod_kategori.sql');
await db.exec(fnText(ys, 'weighted_question_pick', '$f$'));
const fc = read('2026-10-13_friend_challenge.sql');
await db.exec(fnText(fc, 'async_duel_questions_payload', '$$'));
const guards = read('2026-11-01_room_duel_guards.sql');
await db.exec(`create function public.present_async_duel_question(p_duel_id uuid, p_question_index integer) returns jsonb language sql as $$ select jsonb_build_object('started_at', now(), 'elapsed_ms', 0) $$;`);
await db.exec(fnText(guards, 'present_async_duel_question_v2'));
// W2: tablolar + eski işlev gövdeleri + W2 göçünün kendisi (stub çekirdekler).
const solo = read('2026-11-01_solo_daily_verified.sql');
await db.exec(solo.slice(solo.indexOf('create table if not exists public.verified_quiz_cutover'),
  solo.indexOf('create or replace function public.get_verified_daily_question_ids')));
for (const name of ['get_verified_daily_question_ids', 'start_verified_quiz', 'answer_verified_quiz', 'submit_verified_daily_event_result'])
  await db.exec(fnText(solo, name));
await db.exec(`update verified_quiz_cutover set first_day = current_date - 1`);
const room = '60000000-0000-0000-0000-000000000001';
const duel = '70000000-0000-0000-0000-000000000001';
await db.exec(`
create function public.get_room_questions(p_room_id uuid) returns setof jsonb language sql as $$
 select jsonb_build_object('id','${qid(2, 1)}','index',0,'prompt','VISIBLE','option_a','x','correct_option',null)
 union all select jsonb_build_object('id','${qid(2, 2)}','index',1,'prompt','','content_hidden',true)
$$;
create function public._duel_payload() returns jsonb language sql as $$ select jsonb_build_object('duel_id','${duel}','questions','[]'::jsonb) $$;
create function public.start_async_duel(p_category text default null) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.start_async_duel(p_category text, p_request_id uuid) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.create_async_duel_challenge(p_category text default null, p_friend_id uuid default null) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.create_async_duel_challenge(p_category text, p_friend_id uuid, p_request_id uuid) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.accept_async_duel_challenge(p_code text) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.resume_my_async_duel(p_duel_id uuid) returns jsonb language sql as $$ select public._duel_payload() $$;
`);
await db.exec(read('2026-11-16_rekabet_sunum.sql'));
// Canlıdaki gibi: yardımcı olmayan işlevler yalnız service_role/authenticated, anon/PUBLIC kapalı.
await db.exec(`revoke all on function public.weighted_question_pick(uuid[],uuid[],integer) from public, anon, authenticated;
  grant execute on function public.weighted_question_pick(uuid[],uuid[],integer) to service_role;
  revoke all on function public.async_duel_questions_payload(uuid[]) from public, anon, authenticated;
  revoke all on function public.present_async_duel_question_v2(uuid,integer) from public, anon;
  grant execute on function public.present_async_duel_question_v2(uuid,integer) to authenticated;
  revoke all on function public.present_async_duel_question(uuid,integer) from public, anon;`);

const tabanDef = {};
for (const k of ORDER) tabanDef[k] = await defOf(SIG[k]);
const tabanMd5 = Object.fromEntries(ORDER.map(k => [k, md5(tabanDef[k])]));

// ---------- Zincir kanıtı: göçteki taban md5'ler bu zincirden çıkıyor mu ----------
if (process.env.W10_PRINT !== '1') {
  ORDER.forEach((k, i) => assert(forward.includes(`'${SIG[k]}', '${tabanMd5[k]}', '`), 'göçteki taban md5 = zincirden türeyen gövde: ' + k + ' ' + tabanMd5[k]));
  console.log('PASS: altı taban md5 göç dosyalarındaki gerçek gövdelerden yeniden üretildi');
}
const uygula = (sql = forward) => db.exec(sql);
if (process.env.W10_PRINT === '1') {
  let f = forward;
  ORDER.forEach((k, i) => { f = f.replace(`@@TABAN_${i + 1}@@`, tabanMd5[k]).replace(`@@NIHAI_${i + 1}@@`, '0'.repeat(32)); });
  f = f.replace("if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then", 'if false then');
  await uygula(f);
  const out = {};
  for (const k of ORDER) out[k] = {taban: tabanMd5[k], nihai: md5(await defOf(SIG[k]))};
  console.log(JSON.stringify(out, null, 1));
  process.exit(0);
}

await db.exec(`set test.uid='${me}'`);
const pick = async (cands, seen, n) => (await call('weighted_question_pick($1::uuid[],$2::uuid[],$3)', [cands, seen, n])) ?? [];
const idsOf = async (where) => (await q(`select id from questions where ${where}`)).map(r => r.id);
const catOf = async ids => (await q('select distinct category_id c from questions where id = any($1::uuid[])', [ids])).map(r => r.c);

// ---------- ÖN: eski gövdeler; sütun yok ----------
assert.equal((await one("select count(*)::int n from information_schema.columns where table_name='questions' and column_name='server_only'")).n, 0);
const candA0 = await idsOf(`category_id='${catA}'`);
assert.equal((await pick(candA0, [], 10)).length, 10);
console.log('ÖN: göç öncesi seçim çalışıyor, server_only sütunu yok (canlı taban)');

// ---------- GÖÇ ----------
await uygula();
assert.equal((await one("select column_default d from information_schema.columns where table_name='app_runtime_config' and column_name='competitive_server_only_pool'")).d, 'false');
assert.equal((await one("select column_default d from information_schema.columns where table_name='questions' and column_name='server_only'")).d, 'false');
assert.equal((await one("select count(*)::int n from pg_indexes where indexname='questions_server_only_pool_idx'")).n, 1);
assert.equal((await one("select count(*)::int n from olcek_tur3_yedek where ad like 'w10:%'")).n, 6);
// Sunucu-yalnız işaretleme: Cografya'nın 41..80'i (40 adet), Dîrok'un 41..45'i (5 adet).
await db.exec(`update questions set server_only = true where category_id='${catA}' and prompt in (${Array.from({length: 40}, (_, i) => `'COG ${41 + i}'`).join(',')})`);
await db.exec(`update questions set server_only = true where category_id='${catB}' and prompt in ('DIR 41','DIR 42','DIR 43','DIR 44','DIR 45')`);
console.log('PASS: göç uygulandı; sütunlar/varsayılanlar/indeks/6 yedek satırı');

// ---------- Bayrak KAPALI: seçim eskisiyle aynı (hiçbir şey fark edilmemeli) ----------
const candA = await idsOf(`category_id='${catA}'`);
assert.deepEqual(await call('_w10_competitive_pool($1::uuid[],10)', [candA]), candA);
let seenLocal = false;
for (let i = 0; i < 40 && !seenLocal; i++) {
  const p = await pick(candA, [], 10);
  assert.equal(p.length, 10); assert.equal(new Set(p).size, 10);
  const local = await idsOf(`server_only = false and id = any('{${p.join(',')}}'::uuid[])`);
  seenLocal = local.length > 0;
}
assert(seenLocal, 'bayrak kapalıyken yerel sorular da seçilir');
console.log('PASS: bayrak KAPALI -> aday kümesi aynen döner; yerel sorular da seçilir (davranış değişmedi)');

// ---------- Bayrak AÇIK ----------
await db.exec(`update app_runtime_config set competitive_server_only_pool = true where id = 1`);
// (a) Yeterli sunucu-yalnız havuz (40 >= 3*10): yalnız sunucu-yalnız seçilir.
for (let i = 0; i < 30; i++) {
  const p = await pick(candA, [], 10);
  assert.equal(p.length, 10);
  assert.equal((await idsOf(`server_only and id = any('{${p.join(',')}}'::uuid[])`)).length, 10, 'yalnız sunucu-yalnız');
}
// (b) Yetersiz (Dîrok: 5 < 30) -> tüm onaylı havuza düşer (yerel sorular da gelir).
const candB = await idsOf(`category_id='${catB}'`);
let localB = false;
for (let i = 0; i < 40 && !localB; i++) {
  const p = await pick(candB, [], 10);
  assert.equal(p.length, 10);
  localB = (await idsOf(`not server_only and id = any('{${p.join(',')}}'::uuid[])`)).length > 0;
}
assert(localB, 'yetersiz kategoride tüm havuz');
// (c) Hiç sunucu-yalnız yok (Ziman): tüm havuz.
const candZ = await idsOf(`category_id='${catZ}'`);
assert.equal((await pick(candZ, [], 10)).length, 10);
// (d) Karışık pool: kural kategori başına (Ziman yerel + Cografya yalnız sunucu-yalnız + Dîrok tümü).
const mixed = [...candZ, ...candA, ...candB];
const kept = await call('_w10_competitive_pool($1::uuid[],10)', [mixed]);
assert.equal(kept.length, 40 + 40 + 45, 'Ziman 40 + Cografya sunucu-yalnız 40 + Dîrok 45');
assert.equal((await idsOf(`category_id='${catA}' and not server_only and id = any('{${kept.join(',')}}'::uuid[])`)).length, 0);
// (e) Süzgeç sonrası gereken sayının altına düşerse süzgeç yok: yalnız 3 sunucu-yalnız + 0 yerel aday.
const tiny = (await idsOf(`category_id='${catB}' and server_only`)).slice(0, 3);
assert.deepEqual(await call('_w10_competitive_pool($1::uuid[],10)', [tiny]), tiny);
// (f) Görülmüş tercihi bozulmadı: yalnız birkaç görülmüş soru varken seçim yine yalnız sunucu-yalnız,
// tekrarsız ve görülmeyenden doldurulur (zorluk bandı kotası görülmüşü sonda bırakır).
const serverA = await idsOf(`category_id='${catA}' and server_only`);
const seen = serverA.slice(0, 5);
const p = await pick(candA, seen, 10);
assert.equal(p.length, 10); assert.equal(new Set(p).size, 10);
assert.equal((await idsOf(`server_only and id = any('{${p.join(',')}}'::uuid[])`)).length, 10);
// (g) boş / null aday
assert.deepEqual(await call('_w10_competitive_pool(null::uuid[],10)'), []);
assert.deepEqual(await call("_w10_competitive_pool('{}'::uuid[],10)"), []);
console.log('PASS: bayrak AÇIK -> yeterli havuzda yalnız sunucu-yalnız; yetersiz kategoride/Ziman\'da tüm havuz; karışık havuzda kategori başına; küçük havuzda süzgeç yok');

// ---------- Günün yarışması seti ----------
const setOf = async () => (await one('select question_ids ids from verified_daily_question_sets limit 1')).ids;
const resetDaily = () => db.exec('delete from verified_daily_question_sets');
// 40 sunucu-yalnız + 5 = 45 sunucu-yalnız geçerli (>= 30), bayrak açık: set yalnız sunucu-yalnız.
for (let i = 0; i < 8; i++) {
  await resetDaily();
  await db.query('select _w2_daily_set(current_date)');
  const ids = await setOf();
  assert.equal(ids.length, 10);
  assert.equal((await idsOf(`server_only and id = any('{${ids.join(',')}}'::uuid[])`)).length, 10, 'günlük set yalnız sunucu-yalnız');
}
// Sunucu-yalnız geçerli < 30 -> eski havuz (Ziman dahil).
await db.exec(`update questions set server_only = false where category_id='${catA}' and prompt in (${Array.from({length: 20}, (_, i) => `'COG ${41 + i}'`).join(',')})`);
assert.equal((await call('_w10_daily_server_only()')), false); // 20 + 5 = 25 < 30
let dailyLocal = false;
for (let i = 0; i < 12 && !dailyLocal; i++) {
  await resetDaily();
  await db.query('select _w2_daily_set(current_date)');
  dailyLocal = (await idsOf(`not server_only and id = any('{${(await setOf()).join(',')}}'::uuid[])`)).length > 0;
}
assert(dailyLocal, 'yetersiz sunucu-yalnız havuzda günlük set tüm havuzdan');
// Bayrak kapalı: tüm havuz.
await db.exec(`update questions set server_only = true where category_id='${catA}' and prompt in (${Array.from({length: 20}, (_, i) => `'COG ${41 + i}'`).join(',')})`);
await db.exec(`update app_runtime_config set competitive_server_only_pool = false`);
assert.equal(await call('_w10_daily_server_only()'), false);
dailyLocal = false;
for (let i = 0; i < 12 && !dailyLocal; i++) {
  await resetDaily();
  await db.query('select _w2_daily_set(current_date)');
  dailyLocal = (await idsOf(`not server_only and id = any('{${(await setOf()).join(',')}}'::uuid[])`)).length > 0;
}
assert(dailyLocal, 'bayrak kapalıyken günlük set eskisi gibi tüm havuzdan');
// Bugünün seti önceden seçilmişse değişmez (bayrak sonradan açılsa da).
await resetDaily(); await db.query('select _w2_daily_set(current_date)');
const frozen = await setOf();
await db.exec(`update app_runtime_config set competitive_server_only_pool = true`);
await db.query('select _w2_daily_set(current_date)');
assert.deepEqual(await setOf(), frozen);
console.log('PASS: günlük set bayrak açık+yeterli havuzda yalnız sunucu-yalnız; yetersiz/kapalıda eski havuz; seçilmiş gün değişmez');

// ---------- Sunum yanıtları Türkçe karşılığı taşır ----------
await db.exec(`update questions set prompt_tr = 'TR ' || prompt, options_tr = '["a-tr","b-tr","c-tr","d-tr"]'::jsonb where category_id='${catA}' and server_only`);
await resetDaily();
const st = await call('start_verified_daily_v2()');
const pr = await call('present_verified_daily_question($1,0)', [st.round_id]);
assert.match(pr.question.prompt_tr, /^TR COG/); assert.deepEqual(pr.question.options_tr, ['a-tr', 'b-tr', 'c-tr', 'd-tr']);
assert.equal(pr.question.correct_option, undefined);
const withTr = (await idsOf(`prompt_tr is not null`))[0];
const pay = await call('async_duel_questions_payload($1::uuid[])', [[withTr, candZ[0]]]);
assert.equal(pay[0].prompt_tr, 'TR ' + pay[0].prompt); assert.equal(pay[1].prompt_tr, null); assert.equal(pay[1].options_tr, null);
assert.equal(pay[0].correct_option, undefined);
await db.exec(`insert into async_duels values('${duel}', array['${withTr}'::uuid])`);
const dp = await call('present_async_duel_question_v2($1,0)', [duel]);
assert.equal(dp.question.prompt_tr, 'TR ' + dp.question.prompt); assert.deepEqual(dp.question.options_tr, ['a-tr', 'b-tr', 'c-tr', 'd-tr']);
assert.equal(dp.question.correct_option, undefined);
await db.exec(`update questions set prompt_tr = 'TR-ODA', options_tr='["1","2"]' where id='${qid(2, 1)}'`);
const rooms = (await db.query('select get_room_questions_v2($1) r', [room])).rows.map(r => r.r);
assert.equal(rooms[0].prompt_tr, 'TR-ODA'); assert.deepEqual(rooms[0].options_tr, ['1', '2']);
assert.equal(rooms[1].content_hidden, true); assert.equal(rooms[1].prompt_tr, undefined);
assert.notEqual(rooms[1].id, qid(2, 2));
await assert.rejects(db.exec(`update questions set options_tr = '"x"' where id='${qid(2, 1)}'`), /questions_options_tr_shape/);
await assert.rejects(db.exec(`update questions set options_tr = '["a"]' where id='${qid(2, 1)}'`), /questions_options_tr_shape/);
console.log('PASS: günlük/düello/turnuva yükü/oda sunumu prompt_tr + options_tr taşır; gizli satır sızdırmaz; yanlış biçim reddedilir');

// ---------- Yetki ----------
for (const sig of ['public._w10_competitive_pool(uuid[],integer)', 'public._w10_daily_server_only()'])
  for (const role of ['anon', 'authenticated', 'public'])
    assert.equal((await one(`select has_function_privilege('${role}','${sig}','execute') a`)).a, false, role + ' ' + sig);
assert.equal((await one(`select has_function_privilege('service_role','public._w10_daily_server_only()','execute') a`)).a, true);
console.log('PASS: yardımcılar yalnız service_role');

// ---------- İdempotent, yedek zinciri, bozuk/bekleyen durumlar ----------
const nihaiDef = {}; for (const k of ORDER) nihaiDef[k] = await defOf(SIG[k]);
await uygula();
for (const k of ORDER) assert.equal(await defOf(SIG[k]), nihaiDef[k], 'ikinci uygulama no-op: ' + k);
assert.equal((await one("select count(*)::int n from olcek_tur3_yedek where ad like 'w10:%'")).n, 6);
for (const y of await q("select ad, tanim from olcek_tur3_yedek where ad like 'w10:%'"))
  assert(/-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$/.test(y.tanim), 'yedek iki md5 taşır: ' + y.ad);
console.log('PASS: ikinci uygulama idempotent (gövdeler aynı, 6 yedek)');
// Beklenmeyen gövde: nihai de taban da değil -> göç durur.
await db.exec(`create or replace function public._w2_daily_set(p_day date) returns uuid[] language sql security definer set search_path = public, pg_temp as $f$ select '{}'::uuid[] $f$`);
await assert.rejects(uygula(), /ne bilinen canlı taban ne de/); await kapat();
await db.exec(nihaiDef.dailySet);
// Bozuk md5 zinciri.
await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:', '-- md5:0') where ad like 'w10:%'");
await assert.rejects(uygula(), /yedek satırı\/md5 zinciri sağlam değil/); await kapat();
await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:0', '-- md5:') where ad like 'w10:%'");
await uygula();
console.log('PASS: beklenmeyen gövde ve bozuk md5 zinciri göçü durdurur');

// ---------- Geri alma ----------
await geriUygula();
async function geriUygula() { await db.exec(geri); }
for (const k of ORDER) assert.equal(await defOf(SIG[k]), tabanDef[k], 'geri alma birebir: ' + k);
assert.equal((await one("select count(*)::int n from olcek_tur3_yedek where ad like 'w10:%'")).n, 0);
assert.equal((await one("select count(*)::int n from pg_proc where proname in ('_w10_competitive_pool','_w10_daily_server_only')")).n, 0);
// Veri sütunları KALIR (paket 4 satırları kaybolmasın); bayrak sütunu da kalır ama seçim eskiye döner.
assert.equal((await one("select count(*)::int n from information_schema.columns where table_name='questions' and column_name in ('server_only','prompt_tr','options_tr')")).n, 3);
const afterGeri = await pick(candA, [], 10);
assert.equal(afterGeri.length, 10);
await uygula(); // yeniden ileri göç
for (const k of ORDER) assert.equal(await defOf(SIG[k]), nihaiDef[k], 'yeniden ileri: ' + k);
console.log('PASS: geri alma gövdeleri birebir döndürür (yardımcılar düşer, veri sütunları kalır); yeniden ileri göç çalışır');
console.log('TÜM W10 SQL KONTROLLERİ GEÇTİ');
