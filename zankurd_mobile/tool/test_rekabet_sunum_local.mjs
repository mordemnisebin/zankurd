// Yerel PostgreSQL bekçisi (W2): ağ/üretim bağlantısı yok; PGlite bellek DB.
// node tool/test_rekabet_sunum_local.mjs /absolute/path/to/pglite/dist/index.js
// Her kusur ÖNCE eski gövdede gösterilir (RED), sonra yeni göçte kapandığı sınanır (GREEN).
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
const other = '10000000-0000-0000-0000-000000000002';
const nq = 14;
const qid = i => `30000000-0000-0000-0000-${String(i).padStart(12, '0')}`;
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create function public.app_today() returns date language sql stable as $$select coalesce(nullif(current_setting('test.today',true),''), current_date::text)::date$$;
create table profiles(id uuid primary key);
insert into auth.users values('${me}'),('${other}');
insert into profiles values('${me}'),('${other}');
create table categories(id uuid primary key, name text, is_active boolean default true);
insert into categories values('20000000-0000-0000-0000-000000000001','Ziman',true);
create table questions(id uuid primary key, category_id uuid, prompt text, option_a text, option_b text, option_c text, option_d text,
  question_type text, image_url text, difficulty integer default 2, correct_option text, is_approved boolean default true,
  explanation text, explanation_ku text, explanation_tr text);
`);
for (let i = 1; i <= nq; i++) {
  await db.exec(`insert into questions(id,category_id,prompt,option_a,option_b,option_c,option_d,question_type,correct_option,explanation_ku)
    values('${qid(i)}','20000000-0000-0000-0000-000000000001','PROMPT ${i}','a${i}','b${i}','c${i}','d${i}','multiple_choice','${'ABCD'[i % 4]}','AÇIKLAMA ${i}')`);
}
const solo = read('2026-11-01_solo_daily_verified.sql');
// Tablo DDL'i (yedek/izin blokları olmadan) + eski işlevlerin GERÇEK gövdeleri.
await db.exec(solo.slice(solo.indexOf('create table if not exists public.verified_quiz_cutover'),
  solo.indexOf('create or replace function public.get_verified_daily_question_ids')));
for (const name of ['get_verified_daily_question_ids', 'start_verified_quiz', 'answer_verified_quiz', 'submit_verified_daily_event_result'])
  await db.exec(fn(solo, name));
await db.exec(`update verified_quiz_cutover set first_day = current_date - 1`);
await db.exec(`set test.uid='${me}'`);
const opt = async id => (await one('select correct_option o from questions where id=$1', [id])).o;
const today0 = (await one("select current_date::text d")).d;

// ---------- RED: eski günlük yarışma kusurları ----------
const oldIds = (await one('select get_verified_daily_question_ids() ids')).ids;
assert.equal(oldIds.length, 10);
assert(oldIds.every(id => /^30000000-/.test(id)), 'eski yol 10 gerçek soru kimliğini sunumdan önce verir');
console.log('RED #3/#4: eski yol 10 gerçek kimliği sunumdan ÖNCE veriyor (yerel bankayla eşlenir)');
const r1 = '50000000-0000-0000-0000-000000000001';
const r2 = '50000000-0000-0000-0000-000000000002';
await db.query('select start_verified_quiz($1,$2,true,null)', [r1, oldIds]);
for (let i = 0; i < 4; i++) await db.query('select answer_verified_quiz($1,$2,$3)', [r1, oldIds[i], await opt(oldIds[i])]);
await assert.rejects(db.query('select start_verified_quiz($1,$2,true,null)', [r2, oldIds]), /verified_quiz_one_daily_attempt|duplicate/);
console.log('RED #3: 4 cevaptan sonra yeni tur kimliğiyle devam edilemez (günlük hak yanar)');
await db.exec(`update verified_quiz_sessions set day = current_date - 1`);
await assert.rejects(db.query('select answer_verified_quiz($1,$2,$3)', [r1, oldIds[4], await opt(oldIds[4])]), /Session expired/);
console.log('RED #6: gece yarısını aşan oturum cevap yazamaz');
await db.exec(`delete from verified_quiz_sessions`);
await db.exec(`update verified_daily_disclosures set first_seen_at = now() - interval '2 hours'`);
await db.query('select start_verified_quiz($1,$2,true,null)', [r1, oldIds]);
await assert.rejects(db.query('select answer_verified_quiz($1,$2,$3)', [r1, oldIds[0], await opt(oldIds[0])]), /Session expired/);
console.log('RED #14: önceden açılmış listede baştan süresi dolmuş oturum açılır, ilk cevapta hak yanar');
await db.exec(`delete from verified_quiz_sessions; delete from verified_daily_disclosures; delete from verified_daily_question_sets;`);

// ---------- Oda/düello eski sarmalayıcıların SÖZLEŞME çıktısı (canlı gövdeler değil, stub) ----------
const room = '60000000-0000-0000-0000-000000000001';
const duel = '70000000-0000-0000-0000-000000000001';
await db.exec(`
create function public.get_room_questions(p_room_id uuid) returns setof jsonb language sql as $$
 select jsonb_build_object('id','${qid(1)}','prompt','CURRENT','option_a','x','correct_option',null)
 union all select jsonb_build_object('id','${qid(2)}','index',1,'prompt','','content_hidden',true)
$$;
create function public._duel_payload() returns jsonb language sql as $$
 select jsonb_build_object('duel_id','${duel}','questions',jsonb_build_array(
  jsonb_build_object('id','${qid(1)}','index',0,'prompt','','content_hidden',true),
  jsonb_build_object('id','${qid(2)}','index',1,'prompt','','content_hidden',true)))
$$;
create function public.start_async_duel(p_category text default null) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.start_async_duel(p_category text, p_request_id uuid) returns jsonb language sql as $$ select public._duel_payload() || jsonb_build_object('keyed',true) $$;
create function public.create_async_duel_challenge(p_category text default null, p_friend_id uuid default null) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.create_async_duel_challenge(p_category text, p_friend_id uuid, p_request_id uuid) returns jsonb language sql as $$ select public._duel_payload() || jsonb_build_object('keyed',true) $$;
create function public.accept_async_duel_challenge(p_code text) returns jsonb language sql as $$ select public._duel_payload() $$;
create function public.resume_my_async_duel(p_duel_id uuid) returns jsonb language sql as $$ select public._duel_payload() $$;
`);
assert.equal((await db.query('select get_room_questions($1) q', [room])).rows[1].q.id, qid(2));
assert.equal((await call('start_async_duel()')).questions[1].id, qid(2));
console.log('RED #4: eski oda/düello sarmalayıcıları gizli sorunun GERÇEK kimliğini döndürüyor');

// ---------- Göç ----------
const migration = read('2026-11-16_rekabet_sunum.sql');
await db.exec(migration);
await assert.rejects(db.exec(migration), /zaten var/);
await db.exec('rollback');
console.log('PASS: göç uygulandı; ikinci uygulama "yaratılacak nesne zaten var" ile durdu');

// ---------- Günlük akış (yeni yol) ----------
let st = await call('start_verified_daily_v2()');
assert.equal(st.available, true); assert.equal(st.answered, 0); assert.equal(st.total, 10); assert.equal(st.resumed, false);
const round = st.round_id;
assert.deepEqual(Object.keys(st).sort(), ['answered', 'available', 'best_streak', 'completed', 'correct', 'current_streak',
  'day', 'elapsed_ms', 'expired', 'resumed', 'round_id', 'submitted', 'total']);
const setIds = await one(`select question_ids ids, correct_options o from verified_quiz_sessions where client_round_id=$1`, [round]);
const p0 = await call('present_verified_daily_question($1,0)', [round]);
assert.equal(p0.question.prompt, 'PROMPT ' + Number(setIds.ids[0].slice(-12)));
assert.equal(p0.question.correct_option, undefined);
assert.equal(JSON.stringify(p0).includes(setIds.ids[0]), false, 'sunum gerçek kimliği vermez');
assert.equal(JSON.stringify(p0).includes('30000000-'), false);
await assert.rejects(db.query('select present_verified_daily_question($1,1)', [round]), /Invalid index/);
await assert.rejects(db.query(`select answer_verified_daily_question($1,1,'A')`, [round]), /out of sequence/);
console.log('PASS #3/#4: yeni sunum doğru şık/gerçek kimlik içermez, sıra zorunlu');
const a0 = await call(`answer_verified_daily_question($1,0,$2)`, [round, setIds.o[0]]);
assert.equal(a0.is_correct, true); assert.equal(a0.correct_option, setIds.o[0]);
assert.equal(a0.question_id, setIds.ids[0]); assert.equal(a0.completed, false);
assert.match(a0.explanation_ku, /AÇIKLAMA/);
const dup = await call(`answer_verified_daily_question($1,0,'D')`, [round]);
assert.equal(dup.already_answered, true); assert.equal(dup.is_correct, true);
assert.equal((await one('select answered_count n from verified_quiz_sessions where client_round_id=$1', [round])).n, 1);
console.log('PASS: doğru cevap sunucuda; tekrar gönderim ilk cevabı döndürür, ikinci puan yok');
st = await call('start_verified_daily_v2()');
assert.equal(st.resumed, true); assert.equal(st.round_id, round); assert.equal(st.answered, 1); assert.equal(st.correct, 1);
console.log('PASS #3: yarım oturuma kaldığı yerden devam (aynı tur kimliği, cevaplanan sayı)');
const p1 = await call('present_verified_daily_question($1,1)', [round]);
assert.equal((await call('present_verified_daily_question($1,1)', [round])).presented_at, p1.presented_at);
await db.exec(`update verified_quiz_presentations set presented_at = now() - interval '26 seconds' where question_index=1`);
const a1 = await call(`answer_verified_daily_question($1,1,$2)`, [round, setIds.o[1]]);
assert.equal(a1.is_correct, false); assert.equal(a1.correct_option, setIds.o[1]);
console.log('PASS #4: süre sunucuda — sunum saati sıfırlanmaz, 26 sn sonra gelen doğru şık yanlış sayıldı');
await assert.rejects(db.query(`select answer_verified_daily_question($1,2,$2)`, [round, setIds.o[2]]), /Not presented/);
await assert.rejects(db.query(`select answer_verified_daily_question($1,2,'Z')`, [round]), /Invalid choice/);
assert.equal((await call(`answer_verified_daily_question($1,2,'TIMEOUT')`, [round])).is_correct, false);
for (let i = 3; i < 10; i++) {
  await call('present_verified_daily_question($1,$2)', [round, i]);
  await call(`answer_verified_daily_question($1,$2,$3)`, [round, i, setIds.o[i]]);
}
st = await call('start_verified_daily_v2()');
assert.equal(st.completed, true); assert.equal(st.submitted, false); assert.equal(st.answered, 10);
await assert.rejects(db.query('select present_verified_daily_question($1,9)', [round]), /Round completed/);
let sub = await call('submit_verified_daily_event_result_v2($1)', [round]);
assert.equal(sub.submitted, true);
assert.equal((await call('submit_verified_daily_event_result_v2($1)', [round])).submitted, true);
assert.equal((await one('select count(*)::int n from verified_daily_event_results')).n, 1);
assert.equal((await one('select correct_count c from verified_daily_event_results')).c, 8);
assert.equal((await call('start_verified_daily_v2()')).submitted, true);
console.log('PASS #5: sonuç idempotent, kalıcı tur kimliğiyle tekrar gönderilebilir; yeniden açılışta submitted:true');
assert.equal((await call('submit_verified_daily_event_result_v2($1)', ['50000000-0000-0000-0000-0000000000ff'])).reason, 'missing');
await db.exec(`set test.uid='${other}'`);
await assert.rejects(db.query('select present_verified_daily_question($1,0)', [round]), /Verified session missing/);
assert.equal((await call('submit_verified_daily_event_result_v2($1)', [round])).reason, 'missing');
await db.exec(`set test.uid='${me}'`);

// ---------- Gece yarısı (#6) ----------
await db.exec(`delete from verified_daily_event_results; delete from verified_quiz_sessions; delete from verified_daily_question_sets;`);
st = await call('start_verified_daily_v2()');
const midRound = st.round_id;
const midSet = await one(`select question_ids ids, correct_options o from verified_quiz_sessions where client_round_id=$1`, [midRound]);
for (let i = 0; i < 9; i++) {
  await call('present_verified_daily_question($1,$2)', [midRound, i]);
  await call(`answer_verified_daily_question($1,$2,$3)`, [midRound, i, midSet.o[i]]);
}
await db.exec(`update verified_quiz_sessions set day=current_date, started_at = now() - interval '10 minutes'`);
await db.exec(`update verified_quiz_presentations set presented_at = now()`);
await db.exec(`set test.today='${(await one("select (current_date+1)::text d")).d}'`);
st = await call('start_verified_daily_v2()');
assert.equal(st.round_id, midRound, 'dünün yarım oturumu devam eder');
assert.equal(st.day, today0);
await call('present_verified_daily_question($1,9)', [midRound]);
assert.equal((await call(`answer_verified_daily_question($1,9,$2)`, [midRound, midSet.o[9]])).completed, true);
assert.equal((await call('submit_verified_daily_event_result_v2($1)', [midRound])).submitted, true);
assert.equal((await one('select day::text d from verified_daily_event_results')).d, today0);
console.log('PASS #6: gece yarısını aşan oturum devam eder, cevap ve sonuç BAŞLANGIÇ GÜNÜNE yazılır');
await db.exec(`delete from verified_daily_event_results; update verified_quiz_sessions set completed_at = now() - interval '2 hours'`);
assert.equal((await call('submit_verified_daily_event_result_v2($1)', [midRound])).reason, 'late');
st = await call('start_verified_daily_v2()');
assert.notEqual(st.round_id, midRound, 'bir saati geçmiş dünkü gönderilmemiş oturum bugünün yeni turunu engellemez');
await db.exec(`set test.today=''`);

// ---------- #14 ----------
await db.exec(`delete from verified_daily_event_results; delete from verified_quiz_sessions; delete from verified_daily_question_sets;`);
await db.exec(`insert into verified_daily_disclosures(user_id,day,first_seen_at) values('${me}',current_date, now() - interval '2 hours')
  on conflict(user_id,day) do update set first_seen_at = now() - interval '2 hours'`);
st = await call('start_verified_daily_v2()');
assert.equal(st.expired, false);
await call('present_verified_daily_question($1,0)', [st.round_id]);
const fresh = await one(`select correct_options o from verified_quiz_sessions where client_round_id=$1`, [st.round_id]);
assert.equal((await call(`answer_verified_daily_question($1,0,$2)`, [st.round_id, fresh.o[0]])).is_correct, true);
console.log('PASS #14: önceden açıklanmış liste olsa da yeni oturum süresi dolmuş başlamaz');
await db.exec(`update verified_quiz_sessions set started_at = now() - interval '2 hours'`);
st = await call('start_verified_daily_v2()');
assert.equal(st.expired, true);
await assert.rejects(db.query('select present_verified_daily_question($1,1)', [st.round_id]), /Session expired/);
await db.exec(`update verified_quiz_cutover set first_day = current_date + 5`);
assert.equal((await call('start_verified_daily_v2()')).available, false);
await db.exec(`update verified_quiz_cutover set first_day = current_date - 1`);

// ---------- Oda + düello opak belirteç ----------
const rq = (await db.query('select get_room_questions_v2($1) q', [room])).rows.map(r => r.q);
assert.equal(rq[0].id, qid(1), 'açık soru gerçek kimlikle kalır');
assert.notEqual(rq[1].id, qid(2)); assert.match(rq[1].id, /^[0-9a-f-]{36}$/); assert.equal(rq[1].content_hidden, true);
assert.equal(rq[1].id, (await db.query('select get_room_questions_v2($1) q', [room])).rows[1].q.id, 'kararlı');
console.log('PASS #4: oda get_room_questions_v2 gizli soruda opak kararlı belirteç döndürür');
for (const sql of ['start_async_duel_masked()', `start_async_duel_masked('Ziman','${duel}')`, 'create_async_duel_challenge_masked()',
  `create_async_duel_challenge_masked('Ziman',null,'${duel}')`, "accept_async_duel_challenge_masked('X')", `resume_my_async_duel_masked('${duel}')`]) {
  const r = await call(sql);
  assert.equal(r.questions.length, 2);
  for (const q of r.questions) { assert.notEqual(q.id, qid(1)); assert.notEqual(q.id, qid(2)); assert.equal(q.prompt, ''); }
  assert.notEqual(r.questions[0].id, r.questions[1].id);
  assert.equal(r.duel_id, duel);
}
assert.equal((await call(`start_async_duel_masked('Ziman','${duel}')`)).keyed, true, 'istek kimliği tur9 aşırı yüklemesine gider');
console.log('PASS #4: düello sarmalayıcıları (anahtarlı/anahtarsız) sunulmamış soruların gerçek kimliğini vermez');

// ---------- Yetkiler ----------
for (const sig of ['start_verified_daily_v2()', 'present_verified_daily_question(uuid,integer)', 'answer_verified_daily_question(uuid,integer,text)',
  'submit_verified_daily_event_result_v2(uuid)', 'get_room_questions_v2(uuid)', 'start_async_duel_masked(text,uuid)',
  'create_async_duel_challenge_masked(text,uuid,uuid)', 'accept_async_duel_challenge_masked(text)', 'resume_my_async_duel_masked(uuid)']) {
  assert.equal((await one("select has_function_privilege('anon',$1,'execute') a", ['public.' + sig])).a, false, sig);
  assert.equal((await one("select has_function_privilege('authenticated',$1,'execute') a", ['public.' + sig])).a, true, sig);
}
for (const sig of ['_w2_opaque_id(text,integer)', '_w2_daily_set(date)', '_w2_mask_duel_payload(jsonb)'])
  assert.equal((await one("select has_function_privilege('authenticated',$1,'execute') a", ['public.' + sig])).a, false, sig);
await db.exec(`set test.uid=''`);
for (const sql of ['start_verified_daily_v2()', 'start_async_duel_masked()', "get_room_questions_v2('" + room + "')"])
  await assert.rejects(db.query(`select ${sql}`), /Authenticated|Not authenticated/);
console.log('PASS: yetkiler (anon yok, iç yardımcılar kapalı), girişsiz çağrı reddi');

// ---------- Geri alma ----------
await db.exec(read('geri_al/2026-11-16_rekabet_sunum_geri.sql'));
assert.equal((await one("select to_regprocedure('public.start_verified_daily_v2()') is null g")).g, true);
assert.equal((await one("select to_regclass('public.verified_quiz_presentations') is null g")).g, true);
await db.exec(`set test.uid='${me}'`);
assert.equal((await call('start_async_duel()')).questions.length, 2);
await db.exec(migration);
console.log('PASS: geri alma yeni nesneleri kaldırdı, eski işlevler yerinde; yeniden uygulama çalıştı');
await db.close();
