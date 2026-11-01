// G5/G9 bekçisi: beyanla ödül/sıra üretimi günlük tavan ve yalnız biçim
// testleri yüzünden sessizdi. Sadece bellekte PostgreSQL; canlı bağlantı yok.
// PGLITE_MODULE=/absolute/path/to/pglite/dist/index.js node tool/verified_quiz_sql_smoke.mjs
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE_MODULE
  ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite');
const db = await PGlite.create();
const migration = fs.readFileSync(new URL('../supabase/2026-11-01_solo_daily_verified.sql', import.meta.url), 'utf8');
const rollback = fs.readFileSync(new URL('../supabase/geri_al/2026-11-01_solo_daily_verified.sql', import.meta.url), 'utf8');
const uid = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const round = n => `33333333-3333-4333-8333-${String(n).padStart(12, '0')}`;
const one = async (sql, params = []) => (await db.query(sql, params)).rows[0];
const call = async (name, args = []) => (await one(`select public.${name}(${args.map((_, i) => '$' + (i + 1)).join(',')}) as value`, args)).value;
const pass = message => console.log('PASS ' + message);
await db.exec(`
create role anon; create role authenticated;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select current_setting('test.uid', true)::uuid$$;
create function public.app_today() returns date language sql stable as $$select current_setting('test.day')::date$$;
set test.day = '2026-11-01'; set test.uid = '${uid}';
create table public.profiles(id uuid primary key, display_name text);
create table public.categories(id uuid primary key default gen_random_uuid(), name text, is_active boolean);
create table public.questions(id uuid primary key default gen_random_uuid(), category_id uuid references categories(id),
  prompt text, option_a text, option_b text, option_c text, option_d text,
  correct_option text, question_type text, is_approved boolean);
create table public.coin_transactions(id uuid primary key default gen_random_uuid(),player_id uuid,amount integer,reason text,created_at timestamptz default (public.app_today()::timestamp at time zone 'Europe/Istanbul'));
create table public.daily_event_results(day date, user_id uuid, correct_count integer, total_count integer, seconds integer,created_at timestamptz default now());
create function public.claim_solo_reward(p_correct_count integer,p_total_questions integer,p_best_streak integer) returns jsonb language sql security definer as $$select '{"amount":45}'::jsonb$$;
create function public.claim_solo_reward(p_correct_count integer,p_total_questions integer,p_best_streak integer,p_client_round_id uuid) returns jsonb language sql security definer as $$select '{"amount":45}'::jsonb$$;
create function public.submit_daily_event_result(p_correct integer,p_total integer,p_seconds integer) returns boolean language sql security definer as $$select true$$;
create function public.get_daily_event_board() returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('participants', count(*), 'top', coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)) from public.daily_event_results r
$$;
insert into auth.users values('${uid}'),('${other}');
insert into profiles values('${uid}','Synthetic A'),('${other}','Synthetic B');
insert into categories(name,is_active) values('Synthetic',true);
insert into questions(category_id,prompt,option_a,option_b,option_c,option_d,correct_option,question_type,is_approved)
select c.id, 'Synthetic question '||n, 'A','B','C','D','A','multiple_choice',true from categories c cross join generate_series(1,30) n;
insert into daily_event_results values ('2026-11-01','${uid}',20,20,0,now());
`);
await db.exec(migration);
await db.exec(migration);
pass('G5/G9 migration 2x idempotent; live definitions captured once');
assert.equal((await call('claim_solo_reward', [20,20,20])).amount, 0);
assert.equal((await call('claim_solo_reward', [20,20,20,round(1)])).amount, 0);
assert.equal(await call('submit_daily_event_result', [20,20,0]), false);
assert.equal((await call('get_daily_event_board')).participants, 0);
pass('G5/G9 forged totals cannot pay or rank; old records excluded (cap-only tests missed this)');
const funcs = ['prepare_verified_solo_questions(text,integer)', 'start_verified_quiz(uuid,uuid[],boolean,uuid)', 'answer_verified_quiz(uuid,uuid,text)', 'claim_verified_solo_reward(uuid)', 'submit_verified_daily_event_result(uuid)', 'get_verified_daily_event_board()'];
for (const fn of funcs) {
  const acl = await one(`select has_function_privilege('anon',$1,'execute') anon, has_function_privilege('authenticated',$1,'execute') signed`, ['public.' + fn]);
  assert.equal(acl.anon, false); assert.equal(acl.signed, true);
}
await db.exec('set role authenticated');
await assert.rejects(db.query('select * from public.verified_quiz_sessions'), /permission denied/);
await db.exec('reset role');
pass('G5/G9 anon RPC and authenticated raw session/answer access denied');
const prepared = await call('prepare_verified_solo_questions', ['Synthetic', 5]);
assert.equal(Object.hasOwn(prepared, 'correct_options'), false);
const ids = prepared.question_ids;
await assert.rejects(call('start_verified_quiz', [round(1),ids,false,null]), /Server selection required/);
const session = await call('start_verified_quiz', [round(1),ids,false,prepared.selection_id]);
assert.equal(await call('start_verified_quiz', [round(1),ids,false,prepared.selection_id]), session);
await assert.rejects(call('start_verified_quiz', [round(2),ids,false,prepared.selection_id]), /Server selection required/);
assert.equal((await call('claim_verified_solo_reward', [round(1)])).amount, 0);
await assert.rejects(call('answer_verified_quiz', [round(1), ids[1], 'A']), /out of sequence/);
await call('answer_verified_quiz', [round(1),ids[0],'B']);
await call('answer_verified_quiz', [round(1),ids[0],'A']);
for (const id of ids.slice(1)) await call('answer_verified_quiz', [round(1),id,'A']);
assert.equal((await one('select correct_count from public.verified_quiz_sessions where id=$1',[session])).correct_count, 4);
const claim = await call('claim_verified_solo_reward', [round(1)]);
assert.equal(claim.amount, 12);
assert.equal((await call('claim_verified_solo_reward', [round(1)])).already_claimed, true);
assert.equal((await one('select count(*)::int n from coin_transactions')).n, 1);
await db.exec(`set test.uid='${other}'`);
assert.equal((await call('claim_verified_solo_reward', [round(1)])).amount, 0);
await assert.rejects(call('answer_verified_quiz', [round(1),ids[0],'A']), /session missing/);
await db.exec(`set test.uid='${uid}'`);
pass('G5 server selection, answer order, wrong-first retry, owner isolation and payout idempotency');
for (const n of [6,7,8,9]) {
  const ticket = await call('prepare_verified_solo_questions',['Synthetic',5]);
  await call('start_verified_quiz',[round(n),ticket.question_ids,false,ticket.selection_id]);
  for (const id of ticket.question_ids) await call('answer_verified_quiz',[round(n),id,'A']);
  if (n !== 9) await call('claim_verified_solo_reward',[round(n)]);
}
assert.equal((await one("select sum(amount)::int n from coin_transactions")).n,45);
pass('G5 distinct verified rounds still share the 45-coin daily cap');
const daily = await call('get_verified_daily_question_ids');
assert.equal(daily.length, 10);
assert.deepEqual(await call('get_verified_daily_question_ids'), daily);
await assert.rejects(call('start_verified_quiz', [round(3), daily, true, null]), /starts next day/);
pass('G9 migration day cannot spend the daily attempt before the published cutover');
await db.exec("set test.day='2026-11-02'");
const tomorrow = await call('get_verified_daily_question_ids');
await assert.rejects(call('start_verified_quiz', [round(3), ids, true, null]), /set mismatch/);
// Adversary reads questions, waits, then tries starting with a fresh clock.
await db.exec(`update public.verified_daily_disclosures set first_seen_at = clock_timestamp() - interval '20 seconds' where user_id='${uid}' and day='2026-11-02'`);
const before = await one("select first_seen_at::text t from verified_daily_disclosures where day='2026-11-02'");
await call('get_verified_daily_question_ids');
assert.deepEqual(await one("select first_seen_at::text t from verified_daily_disclosures where day='2026-11-02'"),before);
await call('start_verified_quiz',[round(4),tomorrow,true,null]);
await assert.rejects(call('start_verified_quiz',[round(5),tomorrow,true,null]), /duplicate key/);
for (const id of tomorrow) await call('answer_verified_quiz',[round(4),id,'A']);
assert.equal(await call('submit_verified_daily_event_result',[round(4)]),true);
assert.equal(await call('submit_verified_daily_event_result',[round(4)]),true);
const board = await call('get_verified_daily_event_board');
assert.equal(board.participants, 1);
assert.equal(board.top[0].correct_count, 10);
assert.ok(board.top[0].seconds >= 20);
assert.equal((await call('claim_verified_solo_reward',[round(9)])).amount,0);
pass('G9 first disclosure starts clock; repeated fetch cannot reset it; daily attempt/result idempotency');
await db.exec(rollback);
assert.equal((await call('claim_solo_reward',[1,1,1])).amount,45);
assert.equal((await one("select has_function_privilege('authenticated','public.answer_verified_quiz(uuid,uuid,text)','execute') allowed")).allowed,false);
pass('G5/G9 rollback restores runtime-saved functions and closes new RPCs without deleting evidence');
await db.close();
console.log('G5/G9 SQL SMOKE: ALL PASS');
