// Yerel PostgreSQL bekçisi (W2 guard göçü): ağ/üretim bağlantısı yok; PGlite bellek DB.
// node tool/test_rekabet_sunum_guard_local.mjs /absolute/path/to/pglite/dist/index.js
// Canlıdaki işlev gövdeleri göç dosyalarındaki GERÇEK metinlerden kurulur; guard göçündeki
// taban/nihai md5 sabitleri bu zincirden yeniden hesaplanıp karşılaştırılır.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
const call = async (sql, args = []) => (await one(`select ${sql} r`, args)).r;
const fn = (src, name) => {
  const start = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src)?.index ?? -1;
  assert(start >= 0, name);
  const body = src.indexOf('$function$', start);
  return src.slice(start, src.indexOf('$function$;', body + 10) + 11);
};
const me = '10000000-0000-0000-0000-000000000001';
const room = '60000000-0000-0000-0000-000000000001';
const duel = '70000000-0000-0000-0000-000000000001';
const q0 = '30000000-0000-0000-0000-000000000001';
const q1 = '30000000-0000-0000-0000-000000000002';
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create function public.app_today() returns date language sql stable as $$select current_date$$;
create table profiles(id uuid primary key);
insert into auth.users values('${me}'); insert into profiles values('${me}');
create table categories(id uuid primary key, name text, is_active boolean default true);
create table questions(id uuid primary key, category_id uuid, prompt text, option_a text, option_b text, option_c text, option_d text,
  question_type text, image_url text, difficulty integer default 2, correct_option text, is_approved boolean default true,
  explanation text, explanation_ku text, explanation_tr text);
insert into questions(id,prompt,option_a,option_b,correct_option) values('${q0}','CURRENT','A0','B0','A'),('${q1}','FUTURE','A1','B1','B');
insert into categories values('20000000-0000-0000-0000-000000000001','Ziman',true);
insert into questions(id,category_id,prompt,option_a,option_b,option_c,option_d,question_type,correct_option)
  select gen_random_uuid(), '20000000-0000-0000-0000-000000000001', 'p'||g, 'a','b','c','d','multiple_choice','A' from generate_series(1,12) g;
create table rooms(id uuid primary key,host_id uuid,status text,current_question_index integer);
insert into rooms values('${room}','${me}','active',0);
create table room_players(room_id uuid,player_id uuid);
create table room_questions(room_id uuid,question_id uuid,question_index integer,started_at timestamptz);
insert into room_questions values('${room}','${q0}',0,now()),('${room}','${q1}',1,null);
grant select on room_questions to anon, authenticated;
create table olcek_tur3_yedek(ad text primary key, tanim text not null, alindi timestamptz not null default now());
alter table olcek_tur3_yedek enable row level security;
revoke all on olcek_tur3_yedek from public, anon, authenticated;
`);
const solo = read('2026-11-01_solo_daily_verified.sql');
await db.exec(solo.slice(solo.indexOf('create table if not exists public.verified_quiz_cutover'),
  solo.indexOf('create or replace function public.get_verified_daily_question_ids')));
for (const name of ['get_verified_daily_question_ids', 'start_verified_quiz', 'answer_verified_quiz', 'submit_verified_daily_event_result'])
  await db.exec(fn(solo, name));
await db.exec(`revoke all on function public.get_verified_daily_question_ids(), public.start_verified_quiz(uuid,uuid[],boolean,uuid) from public, anon;
grant execute on function public.get_verified_daily_question_ids(), public.start_verified_quiz(uuid,uuid[],boolean,uuid) to authenticated;
update verified_quiz_cutover set first_day = current_date - 1`);
// Canlı çekirdekler (room_duel_guards): gerçek sarmalayıcı gövdeleri + stub çekirdekler.
const guards = read('2026-11-01_room_duel_guards.sql');
await db.exec(`
create function public._guard_20261101_get_room_questions(p_room_id uuid) returns setof jsonb language sql security definer as $$
 select jsonb_build_object('id', q.id, 'prompt', q.prompt, 'option_a', q.option_a, 'correct_option', null)
 from room_questions rq join questions q on q.id = rq.question_id where rq.room_id = p_room_id order by rq.question_index $$;
create function public._payload() returns jsonb language sql as $$
 select jsonb_build_object('duel_id','${duel}','questions', jsonb_build_array(
  jsonb_build_object('id','${q0}','prompt','CURRENT','option_a','A0'), jsonb_build_object('id','${q1}','prompt','FUTURE','option_a','A1'))) $$;
create function public._guard_20261101_start_async_duel(p_category text) returns jsonb language sql as $$ select public._payload() $$;
create function public._guard_20261101_create_async_duel_challenge(p_category text, p_friend_id uuid) returns jsonb language sql as $$ select public._payload() $$;
create function public._guard_20261101_accept_async_duel_challenge(p_code text) returns jsonb language sql as $$ select public._payload() $$;
create function public._guard_20261101_resume_my_async_duel(p_duel_id uuid) returns jsonb language sql as $$ select public._payload() $$;
`);
for (const name of ['get_room_questions', '_guard_20261101_hide_duel_content', 'start_async_duel', 'create_async_duel_challenge', 'accept_async_duel_challenge', 'resume_my_async_duel'])
  await db.exec(fn(guards, name));
await db.exec(`
revoke all on function public.get_room_questions(uuid), public.start_async_duel(text) from public, anon;
grant execute on function public.get_room_questions(uuid), public.start_async_duel(text), public.create_async_duel_challenge(text,uuid),
  public.accept_async_duel_challenge(text), public.resume_my_async_duel(uuid) to authenticated;
revoke all on function public._guard_20261101_hide_duel_content(jsonb) from public, anon, authenticated;
create function public.start_async_duel(p_category text, p_request_id uuid) returns jsonb language sql as $$ select public.start_async_duel(p_category) $$;
create function public.create_async_duel_challenge(p_category text, p_friend_id uuid, p_request_id uuid) returns jsonb language sql as $$ select public.create_async_duel_challenge(p_category, p_friend_id) $$;
`);
await db.exec(`set test.uid='${me}'`);

// ---------- Zincir kanıtı: guard göçündeki md5 sabitleri bu zincirden çıkıyor mu ----------
const guard = read('2026-11-17_rekabet_sunum_guard.sql');
const md5Of = async sig => (await one('select md5(pg_get_functiondef(to_regprocedure($1))) m', [sig])).m;
const claimed = {};
for (const m of guard.matchAll(/\('(public\.[^']+)', '([0-9a-f]{32})', '([0-9a-f]{32})'\)/g)) claimed[m[1]] = {taban: m[2], nihai: m[3]};
assert.deepEqual(Object.keys(claimed).sort(), ['public._guard_20261101_hide_duel_content(jsonb)', 'public.get_room_questions(uuid)', 'public.start_verified_quiz(uuid,uuid[],boolean,uuid)']);
for (const [sig, v] of Object.entries(claimed)) assert.equal(await md5Of(sig), v.taban, 'taban md5 ' + sig);
console.log('PASS: üç taban md5 göç dosyalarındaki gerçek gövdelerden yeniden üretildi');

// ---------- RED: guard öncesi eski yollar açık ----------
const migrationA = read('2026-11-16_rekabet_sunum.sql');
assert.equal((await one("select has_function_privilege('authenticated','public.get_verified_daily_question_ids()','execute') a")).a, true);
assert.equal((await db.query('select get_room_questions($1) q', [room])).rows[1].q.id, q1);
assert.equal((await call('start_async_duel()')).questions[1].id, q1);
assert.equal((await one("select has_table_privilege('authenticated','public.room_questions','select') a")).a, true);
console.log('RED: guard öncesi get_room_questions/düello gerçek kimlik, günlük kimlik işlevi ve room_questions SELECT açık');

// ---------- Guard önkoşulu: A göçü yokken durur ----------
await assert.rejects(db.exec(guard), /beklenen canlı nesneler eksik/);
await db.exec('rollback');
await db.exec(migrationA);
// SECURITY INVOKER işlev room_questions okuyorsa guard durur
await db.exec(`create function public.inv_probe() returns int language sql as $$ select count(*)::int from public.room_questions $$`);
await assert.rejects(db.exec(guard), /SECURITY INVOKER işlev/);
await db.exec('rollback');
await db.exec('drop function public.inv_probe()');

// ---------- Guard ----------
await db.exec(guard);
for (const [sig, v] of Object.entries(claimed)) assert.equal(await md5Of(sig), v.nihai, 'nihai md5 ' + sig);
assert.equal((await one("select count(*)::int n from olcek_tur3_yedek where ad like 'w2:%'")).n, 3);
console.log('PASS: guard uygulandı; nihai md5 sabitleri doğru; 3 yedek satırı');
await db.exec(guard); // idempotent
assert.equal((await one("select count(*)::int n from olcek_tur3_yedek where ad like 'w2:%'")).n, 3);
console.log('PASS: ikinci uygulama idempotent');
// Eski yollar kapalı
await assert.rejects(db.query('select start_verified_quiz($1,$2,true,null)', ['50000000-0000-0000-0000-000000000001', [q0]]), /start_verified_daily_v2/);
assert.equal((await one("select has_function_privilege('authenticated','public.get_verified_daily_question_ids()','execute') a")).a, false);
assert.equal((await one("select has_table_privilege('authenticated','public.room_questions','select') a")).a, false);
assert.equal((await one("select has_table_privilege('anon','public.room_questions','select') a")).a, false);
const hidden = (await db.query('select get_room_questions($1) q', [room])).rows.map(r => r.q);
assert.equal(hidden[0].prompt, 'CURRENT'); assert.equal(hidden[1].prompt, ''); assert.notEqual(hidden[1].id, q1);
const v2 = (await db.query('select get_room_questions_v2($1) q', [room])).rows.map(r => r.q);
assert.equal(v2[1].id, hidden[1].id, 'v2 ve yamalı eski işlev aynı belirteci verir');
for (const sql of ['start_async_duel()', 'create_async_duel_challenge()', "accept_async_duel_challenge('X')", `resume_my_async_duel('${duel}')`]) {
  const r = await call(sql);
  for (const q of r.questions) { assert.notEqual(q.id, q0); assert.notEqual(q.id, q1); assert.equal(q.prompt, ''); assert.equal(q.content_hidden, true); }
}
const masked = await call('start_async_duel_masked()');
const plain = await call('start_async_duel()');
assert.deepEqual(masked.questions.map(q => q.id), plain.questions.map(q => q.id), 'masked ve yamalı sarmalayıcı aynı belirteç');
// Katılımcı doğrudan tablodan okuyamaz
await db.exec('set role authenticated');
await assert.rejects(db.query('select question_id from room_questions'), /permission denied/);
await assert.rejects(db.query('select get_verified_daily_question_ids()'), /permission denied/);
await db.exec('reset role');
// Yeni günlük yol authenticated ile çalışır
await db.exec('set role authenticated');
const st = await call('start_verified_daily_v2()').catch(e => ({hata: String(e.message)}));
await db.exec('reset role');
assert(!st.hata || !/permission/.test(st.hata), 'v2 authenticated için çalışmalı: ' + st.hata);
console.log('PASS: eski yollar kapalı (günlük başlangıç, kimlik işlevi, tablo SELECT), oda/düello opak belirteç, v2 açık');

// ---------- Kimlik koruması: canlı gövde değişmişse guard durur ----------
await db.exec(read('geri_al/2026-11-17_rekabet_sunum_guard_geri.sql'));
for (const [sig, v] of Object.entries(claimed)) assert.equal(await md5Of(sig), v.taban, 'geri alma taban ' + sig);
assert.equal((await one("select count(*)::int n from olcek_tur3_yedek where ad like 'w2:%'")).n, 0);
assert.equal((await one("select has_function_privilege('authenticated','public.get_verified_daily_question_ids()','execute') a")).a, true);
assert.equal((await one("select has_table_privilege('authenticated','public.room_questions','select') a")).a, true);
assert.equal((await db.query('select get_room_questions($1) q', [room])).rows[1].q.id, q1);
console.log('PASS: geri alma üç gövdeyi md5 tabanına birebir döndürdü ve yetkileri geri verdi');
await db.exec(`create or replace function public.get_room_questions(p_room_id uuid) returns setof jsonb language sql as $$ select '{}'::jsonb $$`);
await assert.rejects(db.exec(guard), /ne bilinen canlı taban/);
await db.exec('rollback');
await db.exec(fn(guards, 'get_room_questions'));
await db.exec(guard);
await db.exec(read('geri_al/2026-11-17_rekabet_sunum_guard_geri.sql'));
// Geri alma sonrası araya giren değişiklik: guard geri alma durur
await db.exec(guard);
await db.exec(`create or replace function public.get_room_questions(p_room_id uuid) returns setof jsonb language sql as $$ select '{}'::jsonb $$`);
await assert.rejects(db.exec(read('geri_al/2026-11-17_rekabet_sunum_guard_geri.sql')), /göçün yazdığı gövde değil/);
await db.exec('rollback');
console.log('PASS: bozuk/araya girilmiş gövdede hem ileri göç hem geri alma durur (ya hep ya hiç)');
await db.close();
