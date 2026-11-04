// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_guvenlik_tur7_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-06_guvenlik_tur7.sql için her kusur ÖNCE eski (canlı taban) gövdede
// gösterilir, sonra göç uygulanır ve düzeltme kanıtlanır:
//  1 inceleme sızıntısı, 2 taklit oyuncu kodu, 3 davet sınırı/kilit sırası,
//  4 fcm_token, 5 rapor harf varyantı, 6 öneri kotası created_at, 7 arkadaş
//  isteği geçmişi, 9/10/11/B kilit sırası (metin + çalışma), 13/14 düello kapanışı
//  ve hükmen XP, 16 analitik kilidi, 18 rekor kaynağı, A iade, C turnuva kilidi.
// Sonda: yedek/md5 zinciri, ya hep ya hiç, beklenmeyen gövde, geri alma eski
// gövdeleri birebir döndürür, yeniden ileri göç çalışır.
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
let tur7 = read('2026-11-06_guvenlik_tur7.sql');
const geri = read('geri_al/2026-11-06_guvenlik_tur7_geri.sql');
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const Q = n => 'abcdef00-0000-0000-0000-' + String(n).padStart(12, '0');
const D = n => '60000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const defOnce = async n => (await db.query(`select pg_get_functiondef('public.${n}'::regprocedure) d`)).rows[0].d;
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
const kapat = async () => { try { await db.exec('rollback'); } catch (e) { /* açık işlem yok */ } };

// --- Canlı taban gövdeleri: applied.md ✅ zincirindeki SON tanım ----------------
const olcek = read('2026-11-04_olcek_sertlestirme.sql');
const tur4 = read('2026-11-05_olcek_tur4.sql');
const sosyal = read('2026-10-15_sosyal_ve_sertlestirme.sql');
const bildirim = read('2026-10-24_bildirim_seri_eposta.sql');
const sunucu = read('2026-10-24_sunucu_sertlestirme.sql');
const duelloSirasi = read('2026-10-24_duello_sirasi.sql');
const IMZA = {
  inc: 'get_async_duel_review(uuid)', tag: 'assign_player_tag()', ref: 'redeem_referral_code(text)',
  pins: 'profiles_client_insert_authority()', pwg: 'profiles_client_write_guard()', fcm: 'set_fcm_token(text)',
  rep: 'report_question(text)', repT: 'question_reports_before_insert()', sug: 'limit_suggested_question_rate()',
  frd: 'add_friend(uuid,text)', sday: 'recompute_player_score_day(uuid,date)', exp: 'expire_async_duels()',
  ana: 'log_analytics_event(text,jsonb)', rec: 'get_my_records()', rdy: 'mark_room_client_ready(uuid)',
  hb: 'room_heartbeat(uuid)', jt: 'join_tournament()',
  clm: 'claim_quiz_reward(uuid,integer,integer,integer,integer)',
};
const BASE = {
  inc: () => fnText(read('2026-10-24_duello_inceleme_rovans.sql'), 'get_async_duel_review'),
  tag: () => fnText(read('2026-08-01_player_tag_trigger_permission.sql'), 'assign_player_tag', '$$'),
  ref: () => fnText(sosyal, 'redeem_referral_code'),
  pins: () => fnText(bildirim, 'profiles_client_insert_authority'),
  pwg: () => fnText(bildirim, 'profiles_client_write_guard'),
  fcm: () => fnText(sosyal, 'set_fcm_token'),
  rep: () => fnText(read('2026-10-02_report_question_dedupe.sql'), 'report_question'),
  repT: () => fnText(read('2026-10-02_report_question_dedupe.sql'), 'question_reports_before_insert', '$$'),
  sug: () => fnText(olcek, 'limit_suggested_question_rate'),
  frd: () => fnText(sosyal, 'add_friend'),
  sday: () => fnText(olcek, 'recompute_player_score_day'),
  exp: () => fnText(duelloSirasi, 'expire_async_duels'),
  ana: () => fnText(sunucu, 'log_analytics_event'),
  rec: () => fnText(read('2026-10-24_duello_durtme.sql'), 'get_my_records'),
  rdy: () => fnText(read('2026-10-16_kalabalik_oda.sql'), 'mark_room_client_ready'),
  hb: () => fnText(read('2026-11-03_rovans_oda_sahibi.sql'), 'room_heartbeat'),
  jt: () => fnText(read('2026-07-26_real_player_tournament.sql'), 'join_tournament', '$$'),
  clm: () => fnText(read('2026-10-22_rakip_cikinca_odul.sql'), 'claim_quiz_reward'),
};
// Bu tur kendi yamalarını uygulayan zincir üyeleri (taban, sonradan yamalı canlı gövde).
const yamaCalistir = async (yamaFn, imza, cagrilar) => db.exec('begin;' + yamaFn + cagrilar + 'commit;');

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create table auth.identities(user_id uuid, provider text);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  set check_function_bodies = off;
  create table olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
  create table profiles(id uuid primary key, display_name text, player_tag text unique, referred_by uuid,
    fcm_token text, email_verified_at timestamptz, email_verified_address text, coins int not null default 0,
    rating int not null default 1000, xp int not null default 0, xp_daily_total int not null default 0,
    xp_daily_date date, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
  create table blocked_users(blocker_id uuid, blocked_id uuid);
  create table friends(user_id uuid, friend_id uuid, friend_name text);
  create table friend_requests(id uuid primary key default gen_random_uuid(), from_user_id uuid, from_user_name text,
    to_user_id uuid, status text, created_at timestamptz not null default now(), unique (from_user_id, to_user_id));
  create table coin_transactions(player_id uuid, amount int, reason text);
  create table referral_redemptions(user_id uuid primary key references profiles(id) on delete cascade,
    referrer_id uuid references profiles(id) on delete cascade);
  create table rooms(id uuid primary key default gen_random_uuid(), host_id uuid, status text, ended_reason text,
    finished_at timestamptz, current_question_index int default 0, client_ready_deadline timestamptz,
    is_custom boolean default false, max_players int default 2, seconds_per_question int default 20,
    forfeited_by uuid, rematch_owner_id uuid, last_activity_at timestamptz, entry_fee int default 0, created_at timestamptz default now());
  create table room_players(room_id uuid, player_id uuid, quiz_ready_at timestamptz, left_at timestamptz,
    is_ready boolean, last_seen_at timestamptz, joined_at timestamptz default now(), score int, streak int);
  create table room_questions(room_id uuid, question_index int, question_id uuid, started_at timestamptz);
  create table matchmaking_queue(room_id uuid);
  create table refund_log(room_id uuid, p_except uuid, p_include_left boolean);
  create function public.refund_room_entry_fees(r uuid, e uuid default null, i boolean default false)
    returns integer language sql as $$ insert into refund_log values (r, e, i); select 0 $$;
  create function public.room_lobby_state_json(r uuid) returns json language sql as $$ select '{}'::json $$;
  -- hız sınırı (11-04)
  ${olcek.slice(olcek.indexOf('create table if not exists public.rate_limit_events'), olcek.indexOf('-- 2 + 3b. Oda üyeliği kilidi')).replace(/alter table [^;]*enable row level security;/gi, '').replace(/revoke all[^;]*;/gi, '')}
`);
for (let i = 1; i <= 30; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
}
// Taban gövdeleri kur.
for (const k of Object.keys(BASE)) await db.exec(BASE[k]());
// add_friend: 10-15 gövdesi + 11-04 saatlik sınır yaması (canlı zincir).
{
  const olcekFn = olcek.slice(olcek.indexOf('create or replace function pg_temp.olcek_yama'), olcek.indexOf('$yama$;') + 7);
  const m = olcek.match(/select pg_temp\.olcek_yama\(\s*'public\.add_friend\(uuid,text\)'[\s\S]*?\);\n/);
  assert(m, 'add_friend olcek yamasi');
  await db.exec('begin;' + olcekFn + m[0] + 'commit;');
}
// recompute_player_score_day: 11-04 gövdesi + tur4 toplam yenileme yaması.
{
  const fn = tur4.slice(tur4.indexOf('create or replace function pg_temp.tur4_yama'), tur4.indexOf('$yama$;') + 7);
  const m = tur4.match(/select pg_temp\.tur4_yama\(\s*'public\.recompute_player_score_day\(uuid,date\)'[\s\S]*?\$y\$\);\n/);
  assert(m, 'recompute tur4 yamasi');
  await db.exec(`create or replace function public.refresh_player_score_total(p uuid) returns void language sql as $$ select 1 $$;`);
  await db.exec('begin;' + fn + m[0] + 'commit;');
}
// Yardımcı işlevler (kusur senaryoları için).
await db.exec(fnText(read('2026-07-28_player_tag.sql'), 'generate_player_tag', '$$'));
await db.exec(fnText(sosyal, 'remove_friend'));
await db.exec(`
  create trigger profiles_assign_player_tag before insert on profiles for each row execute function public.assign_player_tag();
  create trigger profiles_client_insert_authority_trg before insert on profiles for each row execute function public.profiles_client_insert_authority();
  create trigger profiles_client_write_guard_trg before update on profiles for each row execute function public.profiles_client_write_guard();
  create table questions(id uuid primary key, report_count int default 0, review_status text,
    prompt text, option_a text, option_b text, option_c text, option_d text, question_type text, correct_option text);
  create table question_reports(id uuid primary key default gen_random_uuid(), reporter_id uuid, question_id text,
    counted_at timestamptz, created_at timestamptz default now());
  create unique index question_reports_reporter_question_uidx on question_reports (reporter_id, question_id);
  create trigger question_reports_before_insert before insert on question_reports for each row execute function public.question_reports_before_insert();
  create table suggested_questions(id uuid primary key default gen_random_uuid(), user_id uuid, created_at timestamptz default now());
  create trigger suggested_questions_rate_limit before insert on suggested_questions for each row execute function public.limit_suggested_question_rate();
  create table analytics_events(user_id uuid, event_name text, event_params jsonb, event_timestamp timestamptz default now());
  create table contest_entries(user_id uuid, correct_count int);
  create table daily_event_results(day date, user_id uuid, correct_count int, total_count int, seconds int, primary key (day, user_id));
  create table player_answers(room_id uuid, player_id uuid, question_id uuid, is_correct boolean);
  create function public.my_duel_tally(u uuid) returns table(n_wins int, n_losses int, n_draws int) language sql as $$ select 0,0,0 $$;
  create table async_duels(id uuid primary key, creator_id uuid, opponent_id uuid, invited_id uuid, status text,
    question_ids uuid[], forfeit_loser_id uuid, expires_at timestamptz default now() + interval '1 day',
    created_at timestamptz default now(), reminder_sent_for uuid[] not null default '{}');
  create table async_duel_answers(duel_id uuid, player_id uuid, question_index int, choice text, is_correct boolean, response_ms int);
  create table async_duel_results(duel_id uuid, player_id uuid, xp_awarded boolean not null default false, correct_count int);
  create table push_outbox(to_user_id uuid, kind text, title text, body text);
  create table xp_log(player_id uuid, amount int);
  create function public.award_xp_delta(a int) returns void language sql as
    $$ insert into xp_log select (current_setting('request.jwt.claims', true)::json->>'sub')::uuid, a $$;
  create function public.async_duel_recent_pair(a uuid, b uuid) returns boolean language sql as $$ select false $$;
  create table tournaments(id uuid primary key default gen_random_uuid(), size int not null default 4,
    status text not null default 'open', opened_at timestamptz not null default now());
  create table tournament_entries(tournament_id uuid not null, player_id uuid not null, display_name text not null,
    primary key (tournament_id, player_id));
  create function public.start_tournament(t uuid) returns void language sql as $$ select 1 $$;
  create function public.app_today() returns date language sql as $$ select current_date $$;
`);
// Canlı ACL'i taklit et: istemci RPC'leri anon/PUBLIC'e kapalı, authenticated açık.
for (const k of Object.keys(IMZA)) {
  if (['tag', 'pins', 'pwg', 'repT', 'sug'].includes(k)) continue; // tetikleyici işlevler
  await db.exec(`revoke all on function public.${IMZA[k]} from public, anon; grant execute on function public.${IMZA[k]} to authenticated`);
}
await db.exec(`grant all on all tables in schema public to authenticated; grant execute on all functions in schema public to authenticated`);
for (const k of Object.keys(IMZA)) {
  if (['tag', 'pins', 'pwg', 'repT', 'sug'].includes(k)) continue;
  await db.exec(`revoke all on function public.${IMZA[k]} from public, anon`);
}

const tabanDef = {};
for (const [k, v] of Object.entries(IMZA)) tabanDef[k] = await defOnce(v);
const tabanMd5 = Object.fromEntries(Object.entries(tabanDef).map(([k, v]) => [k, md5(v)]));
if (process.env.TUR7_PRINT_MD5) { console.log(JSON.stringify(tabanMd5)); process.exit(0); }
for (const k of Object.keys(IMZA)) tur7 = tur7.replace('TABAN_' + k + "'", tabanMd5[k] + "'");
if (process.env.TUR7_PRINT_FINAL) {
  tur7 = tur7.replace('if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then', 'if false then');
  await db.exec(tur7);
  const out = {};
  for (const [k, v] of Object.entries(IMZA)) out[k] = md5(await defOnce(v));
  console.log(JSON.stringify(out));
  process.exit(0);
}
for (const [k, h] of Object.entries(tabanMd5)) assert(read('2026-11-06_guvenlik_tur7.sql').includes(h), 'göçteki taban md5 = repo zincirinden türeyen gövde: ' + k);

// ================ ÖN: kusurlar eski gövdede =====================
const ok = async (n, fn) => { await as(n); try { return await fn(); } finally { await as(0); } };
// 1 inceleme sızıntısı
for (let i = 1; i <= 3; i++) {
  await db.query(`insert into questions values ($1, 0, null, 'S'||$2, 'a','b','c','d','multiple_choice','B')`, [Q(i), i]);
}
await db.query(`insert into async_duels(id, creator_id, opponent_id, status, question_ids, expires_at)
  values ($1, $2, null, 'expired', $3, now())`, [D(1), U(1), [Q(1), Q(2), Q(3)]]);
await db.query(`insert into async_duels(id, creator_id, opponent_id, status, question_ids)
  values ($1, $2, $3, 'completed', $4)`, [D(2), U(1), U(2), [Q(1), Q(2), Q(3)]]);
for (let i = 0; i < 3; i++) await db.query(`insert into async_duel_answers values ($1,$2,$3,'B',true,900)`, [D(2), U(1), i]);
await db.query(`insert into async_duels(id, creator_id, opponent_id, status, question_ids, expires_at)
  values ($1, $2, $3, 'expired', $4, now())`, [D(3), U(1), U(2), [Q(1), Q(2), Q(3)]]);
await db.query(`insert into async_duel_answers values ($1,$2,0,'A',false,500)`, [D(3), U(1)]);
const incele = async d => (await ok(1, () => one('select public.get_async_duel_review($1) r', [d]))).r.questions;
assert.equal((await incele(D(1))).length, 3, 'TABAN KUSURU: iptal edilmiş, hiç oynanmamış düello 3 doğru şıkkı açar');
assert((await incele(D(1))).every(q => q.correct_option === 'B'));
assert.equal((await incele(D(2))).length, 3);
assert.equal((await incele(D(3))).length, 3, 'TABAN: süresi dolmuş düello oynanmamış soruların anahtarını da açar');

// 2 taklit oyuncu kodu
await db.exec(`set role authenticated`);
await db.query("insert into profiles(id, display_name, player_tag) values ($1,'M','ZK-ABCD')", [U(21)]);
await db.exec('reset role');
assert.equal((await one('select player_tag t from profiles where id=$1', [U(21)])).t, 'ZK-ABCD', 'TABAN KUSURU: istemci INSERT\'inde dolu etiket kabul edilir');
await db.query("insert into profiles(id, display_name, player_tag) values ($1,'R','4F7K')", [U(1)]);
await db.query("insert into profiles(id, display_name, player_tag) values ($1,'Mimic','ZK-4F7K')", [U(22)]);
await db.query("insert into profiles(id, display_name) values ($1,'Caller'), ($2,'Caller2'), ($3,'Caller3')", [U(3), U(4), U(5)]);
for (const n of [3, 4, 5]) {
  await db.query("insert into auth.identities values ($1,'google')", [U(n)]);
  await db.query("insert into coin_transactions values ($1, 10, 'solo_round')", [U(n)]);
}
const refKime = async n => (await ok(n, () => one("select public.redeem_referral_code('ZK-4F7K') r", []))).r;
{
  const r = await refKime(3);
  assert.equal(r.success, true);
  assert.equal((await one('select referrer_id::text x from referral_redemptions where user_id=$1', [U(3)])).x, U(22), 'TABAN KUSURU: paylaşılan ZK-4F7K taklit profile eşleşir');
  await db.exec('delete from referral_redemptions; update profiles set referred_by = null; delete from coin_transactions where reason like \'referral%\'');
}
// 3 ömür boyu sınır silinen davet edilenle kaybolur
for (let i = 0; i < 10; i++) await db.query("insert into coin_transactions values ($1, 100, 'referral_invite')", [U(1)]);
await db.query("update profiles set player_tag = 'ZK-OLD1' where id = $1", [U(22)]); // taklit çakışması bu senaryoda yok
{
  const r = (await ok(4, () => one("select public.redeem_referral_code('4F7K') r"))).r;
  assert.equal(r.success, true, 'TABAN KUSURU: 10 ödül jeton olarak verilmiş ama kayıt (cascade) silinmiş: 11. ödül verilir');
  await db.exec('delete from referral_redemptions; update profiles set referred_by = null; delete from coin_transactions where reason = \'referral_welcome\'');
  await db.exec("delete from coin_transactions where reason = 'referral_invite'");
}
// 4 fcm_token
await db.exec('set role authenticated');
await db.query("insert into profiles(id, display_name, fcm_token) values ($1,'F','tok-1')", [U(23)]);
await db.exec(`select set_config('test.uid', '${U(23)}', false)`);
await db.query("update profiles set fcm_token = 'tok-2' where id=$1", [U(23)]);
await db.exec('reset role');
assert.equal((await one('select fcm_token t from profiles where id=$1', [U(23)])).t, 'tok-2', 'TABAN KUSURU: istemci profil INSERT/UPDATE\'iyle fcm_token yazar');
await as(0);
// 5 rapor harf varyantı
const QU = Q(1).toUpperCase(), QL = Q(1);
await db.exec('update questions set report_count = 0');
for (const v of [QU, QL]) {
  await db.query('insert into question_reports(reporter_id, question_id) values ($1,$2)', [U(6), v]);
  await db.exec(`select set_config('test.uid', '${U(6)}', false)`);
  await db.query('select public.report_question($1)', [v]);
}
await as(0);
assert.equal((await one('select report_count c from questions where id=$1', [Q(1)])).c, 2, 'TABAN KUSURU: tek hesap aynı UUID\'nin iki harf varyantını iki rapor sayar');
await db.exec('delete from question_reports; update questions set report_count = 0');
// 6 öneri kotası
await as(7);
for (let i = 0; i < 12; i++) await db.query('insert into suggested_questions(user_id, created_at) values ($1, null)', [U(7)]);
await as(0);
assert.equal((await one('select count(*)::int c from suggested_questions where user_id=$1', [U(7)])).c, 12, 'TABAN KUSURU: created_at=NULL öneriler kotaya girmez');
await db.exec('delete from suggested_questions');
// 7 arkadaş isteği geçmişi silinerek bekleme aşılır
await db.query("insert into profiles(id, display_name) values ($1,'A'), ($2,'B')", [U(8), U(9)]);
{
  await as(8);
  assert.equal((await one('select message m from public.add_friend($1,$2)', [U(9), 'x'])).m, 'Friend request sent');
  await db.query('select * from public.remove_friend($1)', [U(9)]);
  assert.equal((await one('select message m from public.add_friend($1,$2)', [U(9), 'x'])).m, 'Friend request sent',
    'TABAN KUSURU: gönder -> remove_friend -> yeniden gönder: saatlik bekleme aşılır');
  await as(0);
  await db.exec("delete from friend_requests; delete from rate_limit_events");
}
// 13/14 düello kapanışı ve eski hükmen XP
await db.query("insert into profiles(id, display_name) values ($1,'W'), ($2,'L'), ($3,'Gone')", [U(10), U(11), U(12)]).catch(() => {});
await db.query(`insert into async_duels(id, creator_id, opponent_id, status, forfeit_loser_id, expires_at)
  values ($1,$2,$3,'expired',$2, now() - interval '30 days')`, [D(10), U(11), U(10)]);
await db.query(`insert into async_duel_results values ($1,$2,false,3)`, [D(10), U(10)]);
await db.query(`insert into async_duels(id, creator_id, opponent_id, status, forfeit_loser_id, expires_at)
  values ($1,$2,$3,'expired',$2, now() - interval '30 days')`, [D(11), U(11), U(13)]);
await db.query(`insert into async_duel_results values ($1,$2,false,2)`, [D(11), U(13)]); // U13'ün profili yok
for (let i = 0; i < 3; i++) {
  await db.query(`insert into async_duels(id, creator_id, opponent_id, status, expires_at)
    values ($1,$2,$3,'matched', now() - interval '1 hour')`, [D(20 + i), U(14 + i), U(17 + i)]);
}
await db.query('select public.expire_async_duels()');
assert.equal((await one('select count(*)::int c from xp_log')).c, 0, 'TABAN KUSURU: 7 günden eski hükmen kazananın XP\'si hiç ödenmez');
assert.equal((await one("select count(*)::int c from async_duels where status = 'expired' and id::text like '60000000-0000-0000-0000-0000000000_%' and expires_at > now() - interval '2 hours' and id in ($1,$2,$3)", [D(20), D(21), D(22)])).c, 3);
await db.exec("update async_duels set status = 'matched' where id in ('" + [D(20), D(21), D(22)].join("','") + "')");
// 16 analitik, 18 rekor
await db.query("insert into daily_event_results values (current_date, $1, 9, 10, 40)", [U(24)]);
await db.query("insert into contest_entries values ($1, 5)", [U(25)]);
await db.query("insert into daily_event_results values (current_date, $1, 3, 10, 40)", [U(25)]);
await db.query("insert into profiles(id, display_name) values ($1,'R1'),($2,'R2')", [U(24), U(25)]).catch(() => {});
const rekor = async n => (await ok(n, () => one('select public.get_my_records() r'))).r.best_contest_correct;
assert.equal(await rekor(24), null, 'TABAN KUSURU: günlük yarışma rekoru yeni tablodan okunmaz');
// A iade (2 kişilik ücretli oda, hazır olma süresi doldu)
const rdyOda = async (id, host) => {
  await db.query(`insert into rooms(id, host_id, status, client_ready_deadline, is_custom, max_players, entry_fee)
    values ($1,$2,'active', now() - interval '1 minute', false, 2, 50)`, [id, host]);
  await db.query('insert into room_players(room_id, player_id) values ($1,$2),($1,$3)', [id, U(26), U(27)]);
  await db.query('insert into room_questions values ($1, 0, $2, null)', [id, Q(1)]);
};
const R = n => '20000000-0000-0000-0000-' + String(n).padStart(12, '0');
await rdyOda(R(1), U(26));
{
  const r = (await ok(26, () => one('select public.mark_room_client_ready($1) r', [R(1)]))).r;
  assert.equal(r.status, 'finished'); assert.equal(r.reason, 'opponent_not_ready');
  assert.equal((await one('select count(*)::int c from refund_log')).c, 0, 'TABAN KUSURU: opponent_not_ready ücretli odada iade yok');
}
// C turnuva: tek çağrı çalışır (kilit eklemesi davranışı bozmaz)
{
  const r1 = (await ok(1, () => one('select public.join_tournament() r'))).r;
  const r2 = (await ok(1, () => one('select public.join_tournament() r'))).r;
  assert.equal(r1.tournament_id, r2.tournament_id);
  await db.exec('delete from tournament_entries; delete from tournaments');
}

// ============================ GÖÇ ============================
const uygula = () => db.exec(tur7);
await uygula();
await uygula(); // idempotent
assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur7:%'")).c, 18, '18 yedek');
console.log('göç iki kez uygulandı (idempotent)');

// ---- Düzeltmeler ----
// 1
assert.equal((await incele(D(1))).length, 0, 'iptal edilmiş düello hiçbir anahtar açmaz');
assert.equal((await incele(D(2))).length, 3, 'tamamlanmış düello tüm cevaplanan soruları açar');
assert.equal((await incele(D(3))).length, 1, 'yalnız cevaplanan soru açılır');
console.log('1: inceleme yalnız cevaplanan soruları açar');
// 2
{
  await db.exec('set role authenticated');
  await db.query("insert into profiles(id, display_name, player_tag) values ($1,'M2','ZK-WXYZ')", [U(28)]);
  await db.exec('reset role');
  const t = (await one('select player_tag t from profiles where id=$1', [U(28)])).t;
  assert(/^[2-9BCDFGHJKMNPQRSTVWXYZ]{4}$/.test(t) && t !== 'ZK-WXYZ', 'istemci etiketi yok sayıldı, sunucu üretti: ' + t);
  await db.query("insert into profiles(id, display_name, player_tag) values ($1,'S','zk-ab23')", [U(29)]);
  assert.equal((await one('select player_tag t from profiles where id=$1', [U(29)])).t, 'AB23', 'sunucu yolunda önek atılır, büyük harf');
  await db.query("update profiles set player_tag = '4F7K' where id = $1", [U(1)]).catch(() => {});
  await db.query("update profiles set player_tag = 'ZK-4F7K' where id = $1", [U(22)]);
  const r = await refKime(3);
  assert.equal(r.success, true);
  assert.equal((await one('select referrer_id::text x from referral_redemptions where user_id=$1', [U(3)])).x, U(1), 'ZK-4F7K gerçek sahibe (4F7K) eşleşir, taklide değil');
  await db.exec('delete from referral_redemptions; update profiles set referred_by = null; delete from coin_transactions where reason in (\'referral_welcome\',\'referral_invite\')');
  console.log('2: istemci etiketi yok sayılır; ZK- önekli kod gerçek sahibe gider');
}
// 3
{
  for (let i = 0; i < 10; i++) await db.query("insert into coin_transactions values ($1, 100, 'referral_invite')", [U(1)]);
  const r = (await ok(4, () => one("select public.redeem_referral_code('ZK-4F7K') r"))).r;
  assert.equal(r.success, false); assert.equal(r.error, 'limit_reached', 'silinen davet edilen kaydı sınırı düşürmez');
  await db.exec("delete from coin_transactions where reason = 'referral_invite'");
  const d = await defOnce(IMZA.ref);
  assert(d.indexOf('order by id') > 0 && d.indexOf('order by id') < d.indexOf('select id, referred_by, player_tag'), 'iki profil id sırasıyla tek sorguda kilitlenir');
  assert(!d.includes("or replace(player_tag, 'ZK-', '') = v_clean_code"), 'eski OR\'lu arama kalktı');
  console.log('3/11: ömür boyu sınır jeton hareketinden; kilit sırası id');
}
// 4
{
  await db.exec('set role authenticated');
  await db.query("insert into profiles(id, display_name, fcm_token) values ($1,'F2','tok-9')", [U(30)]);
  await db.exec(`select set_config('test.uid', '${U(30)}', false)`);
  await db.query("update profiles set fcm_token = 'tok-x' where id=$1", [U(30)]);
  await db.exec('reset role');
  assert.equal((await one('select fcm_token t from profiles where id=$1', [U(30)])).t, null, 'istemci INSERT\'te token NULL');
  await db.query("update profiles set fcm_token = 'tok-ok' where id=$1", [U(30)]); // definer/yönetici yolu
  await db.exec('set role authenticated');
  await db.query("update profiles set fcm_token = 'tok-x2' where id=$1", [U(30)]);
  await db.exec('reset role');
  assert.equal((await one('select fcm_token t from profiles where id=$1', [U(30)])).t, 'tok-ok', 'istemci UPDATE\'i token\'ı değiştiremez');
  await as(30);
  await db.query("select public.set_fcm_token('tok-new')");
  await as(0);
  assert.equal((await one('select fcm_token t from profiles where id=$1', [U(30)])).t, 'tok-new', 'RPC yazar (definer: current_user istemci değil)');
  assert((await defOnce(IMZA.fcm)).includes("pg_advisory_xact_lock(hashtextextended('fcm:' || v_token, 0))"));
  console.log('4: fcm_token yalnız RPC ile yazılır');
}
// 5
{
  for (const v of [QU, QL]) {
    await db.query('insert into question_reports(reporter_id, question_id) values ($1,$2)', [U(6), v]);
  }
  assert.equal((await one("select count(*)::int c from question_reports where reporter_id=$1", [U(6)])).c, 1, 'ikinci harf varyantı atlanır');
  await db.exec(`select set_config('test.uid', '${U(6)}', false)`);
  await db.query('select public.report_question($1)', [QU]);
  await db.query('select public.report_question($1)', [QL]);
  await as(0);
  assert.equal((await one('select report_count c from questions where id=$1', [Q(1)])).c, 1, 'tek hesap tek sayım');
  console.log('5: harf varyantı tek rapor');
}
// 6
{
  await as(7);
  let r = 0;
  for (let i = 0; i < 12; i++) {
    try { await db.query('insert into suggested_questions(user_id, created_at) values ($1, null)', [U(7)]); r++; } catch (e) { assert(/suggestion_rate_limited/.test(e.message)); break; }
  }
  await as(0);
  assert.equal(r, 10, 'created_at NULL verilse de 10. öneriden sonra ret');
  assert((await one('select count(*)::int c from suggested_questions where created_at is null')).c === 0);
  console.log('6: öneri kotası sunucu saatiyle');
}
// 7
{
  await as(8);
  assert.equal((await one('select message m from public.add_friend($1,$2)', [U(9), 'x'])).m, 'Friend request sent');
  await db.query('select * from public.remove_friend($1)', [U(9)]);
  assert.equal((await one('select message m from public.add_friend($1,$2)', [U(9), 'x'])).m, 'Friend request cooldown', 'geçmiş silinse de saatlik bekleme sürer');
  await as(0);
  console.log('7: arkadaş isteği bekleme/günlük sınır rate_limit_events kovalarında');
}
// 10/9/B/16: kilit sırası
{
  const g = await defOnce(IMZA.sday);
  assert(g.indexOf("'score-total:'") > 0 && g.indexOf("'score-total:'") < g.indexOf("'score-daily:'"), 'önce toplam sonra gün kilidi');
  const c = await defOnce(IMZA.clm); 
  assert(c.indexOf('for update of r') > 0 && c.indexOf('for update of r') < c.indexOf('from public.profiles where id = v_player_id for update'), 'claim_quiz_reward: oda -> profil');
  assert.equal((c.match(/profiles where id = v_player_id for update/g) || []).length, 1);
  const h = await defOnce(IMZA.hb);
  assert(h.indexOf('for update;') > 0 && h.indexOf("perform 1 from public.rooms r where r.id = p_room_id for update") < h.indexOf('update public.room_players rp'), 'heartbeat: rooms -> room_players');
  const a = await defOnce(IMZA.ana);
  assert(a.indexOf("'analytics:' || v_user_id") > 0 && a.indexOf("'analytics:' || v_user_id") < a.indexOf('select count(*)::integer into v_recent'), 'analitik: sayımdan önce kilit');
  const j = await defOnce(IMZA.jt);
  assert(j.indexOf("'tournament-join:'") > 0 && j.indexOf("'tournament-join:'") < j.indexOf('join public.tournament_entries e'), 'turnuva: üyelik kontrolünden önce kullanıcı kilidi');
  assert(j.indexOf("'tournament-alloc'") > j.indexOf('join public.tournament_entries e'));
  // heartbeat gerçek çalışma: sessiz sahip -> devir (lobi)
  await db.query(`insert into rooms(id, host_id, status, is_custom) values ($1,$2,'lobby',true)`, [R(5), U(26)]);
  await db.query(`insert into room_players(room_id, player_id, last_seen_at) values ($1,$2, now() - interval '5 minutes'), ($1,$3, now())`, [R(5), U(26), U(27)]);
  await ok(27, () => db.query('select public.room_heartbeat($1)', [R(5)]));
  assert.equal((await one('select host_id::text h from rooms where id=$1', [R(5)])).h, U(27), 'heartbeat sahiplik devri çalışır');
  // sessiz sahip yoksa oda satırı kilitlenmez: ikinci bağlantı yok, bu yüzden yalnız metinle: ön okuma koşulu
  assert(h.includes('v_kilit_once'), 'ön okuma');
  // turnuva: bir kez katılım, ikinci çağrı aynı
  const r1 = (await ok(1, () => one('select public.join_tournament() r'))).r;
  const r2 = (await ok(1, () => one('select public.join_tournament() r'))).r;
  assert.equal(r1.tournament_id, r2.tournament_id);
  assert.equal((await one('select count(*)::int c from tournaments')).c, 1);
  // analitik normal yol
  await ok(1, () => db.query("select * from public.log_analytics_event('e', null)"));
  assert.equal((await one('select count(*)::int c from analytics_events')).c, 1);
  console.log('9/10/B/C/16: kilit sıraları ve normal yollar');
}
// 13/14
{
  await db.query('select public.expire_async_duels()');
  assert.equal((await one('select count(*)::int c from xp_log')).c, 1, 'KALICI durum: 30 günlük hükmen kazananın XP\'si ödenir (profili olmayan hariç)');
  assert.deepEqual(await one('select player_id::text p, amount a from xp_log'), {p: U(10), a: 3 * 20 + 30});
  assert.equal((await one('select xp_awarded x from async_duel_results where player_id=$1', [U(10)])).x, true);
  assert.equal((await one('select xp_awarded x from async_duel_results where player_id=$1', [U(13)])).x, false);
  await db.query('select public.expire_async_duels()');
  assert.equal((await one('select count(*)::int c from xp_log')).c, 1, 'ikinci koşu çift ödemez');
  assert.equal((await one("select count(*)::int c from async_duels where status = 'expired' and id in ($1,$2,$3)", [D(20), D(21), D(22)])).c, 3, 'süresi dolan düellolar kapanır');
  const e = await defOnce(IMZA.exp);
  assert(e.includes('order by d.expires_at, d.id\n    limit 500\n    for update of d skip locked'));
  console.log('13/14: düello kapanışı sınırlı + SKIP LOCKED; hükmen XP kalıcı duruma bağlı');
}
// 18
{
  assert.equal(await rekor(24), 9, 'günlük yarışma rekoru daily_event_results\'tan');
  assert.equal(await rekor(25), 5, 'eski tablo daha büyükse o');
  console.log('18: rekor iki kaynağın en büyüğü');
}
// A
{
  await rdyOda(R(2), U(26));
  await db.exec('delete from refund_log');
  const r = (await ok(26, () => one('select public.mark_room_client_ready($1) r', [R(2)]))).r;
  assert.equal(r.reason, 'opponent_not_ready');
  const log = await db.query('select room_id::text r, p_except, p_include_left i from refund_log');
  assert.equal(log.rows.length, 1); assert.equal(log.rows[0].r, R(2)); assert.equal(log.rows[0].p_except, null); assert.equal(log.rows[0].i, true);
  console.log('A: 2 kişilik odada opponent_not_ready iade eder');
}

// Bekleyen solo_daily_verified göçünün get_my_records eki (tur7 sonrası gövdeye uygulanır).
{
  const recYamali = await defOnce(IMZA.rec);
  const pend = read('2026-11-01_solo_daily_verified.sql');
  const blok = pend.slice(pend.indexOf('do $rekor$'), pend.indexOf('$rekor$;') + 8);
  assert(blok.startsWith('do $rekor$') && blok.endsWith('$rekor$;'), 'rekor bloğu bulundu');
  await db.exec('create table verified_daily_event_results(day date, user_id uuid, correct_count int)');
  await db.exec(blok);
  await db.exec(blok); // idempotent
  await db.query('insert into verified_daily_event_results values (current_date, $1, 10)', [U(24)]);
  assert.equal(await rekor(24), 10, 'doğrulanmış günlük sonuç da rekora girer');
  await db.query('delete from verified_daily_event_results');
  await db.exec('drop table verified_daily_event_results');
  await db.exec(recYamali); // sonraki geri alma testleri tur7 gövdesini bekler
}
// ======================= Güvenlik / yedek / geri alma =======================
{
  for (const v of Object.values(IMZA)) {
    const p = await one(`select prosecdef, proconfig, prorettype = 'trigger'::regtype tg, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('public', p.oid, 'execute') b from pg_proc p where p.oid = 'public.${v}'::regprocedure`);
    assert(p.proconfig, v);
    if (!p.tg) assert(p.prosecdef && !p.a && !p.b, v);
  }
  const ya = (await db.query("select ad, tanim from olcek_tur3_yedek where ad like 'tur7:%'")).rows;
  assert.equal(ya.length, 18);
  for (const y of ya) assert(/-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$/.test(y.tanim), 'yedek iki md5 taşır: ' + y.ad);
  const yamali = {};
  for (const [k, v] of Object.entries(IMZA)) yamali[k] = await defOnce(v);
  const yedekler = (await db.query('select * from olcek_tur3_yedek')).rows;
  // yeni yetki: anon çağıramaz
  await db.exec('set role anon');
  await assert.rejects(db.query('select public.get_my_records()'), /permission denied/); await kapat();
  await db.exec('reset role');

  // Ya hep ya hiç: tek yedek eksik -> hiçbir şey dönmez.
  await db.exec("delete from olcek_tur3_yedek where ad = 'tur7:public.get_my_records()'");
  await assert.rejects(db.exec(geri), /yedek satırı yok/); await kapat();
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOnce(v), yamali[k], 'eksik yedekte ' + k + ' dönmedi');
  await db.query("insert into olcek_tur3_yedek select * from unnest($1::text[], $2::text[], $3::timestamptz[]) on conflict do nothing",
    [yedekler.map(y => y.ad), yedekler.map(y => y.tanim), yedekler.map(y => y.alindi)]);
  // Bozuk md5 zinciri.
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:', '-- md5:0') where ad like 'tur7:%'");
  await assert.rejects(db.exec(geri), /bozuk/); await kapat();
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:0', '-- md5:') where ad like 'tur7:%'");
  // Uygulanmış dalda yedek yoksa ileri göç durur.
  const kopya = (await db.query("select * from olcek_tur3_yedek where ad like 'tur7:%'")).rows;
  await db.exec("delete from olcek_tur3_yedek where ad like 'tur7:%'");
  await assert.rejects(uygula(), /yedek satırı\/md5 zinciri sağlam değil/); await kapat();
  for (const y of kopya) await db.query('insert into olcek_tur3_yedek values ($1,$2,$3)', [y.ad, y.tanim, y.alindi]);
  // Göçten sonra gövde değişmişse geri alma durur.
  await db.exec(yamali.rec.replace('union all', 'union all /*x*/'));
  await assert.rejects(db.exec(geri), /canlı gövdesi göçten sonra değişmiş/); await kapat();
  await db.exec(yamali.rec);
  // Sızdıran yedek ACL'i: ileri göç durur.
  await db.exec('create role baska; grant select on olcek_tur3_yedek to baska');
  await assert.rejects(uygula(), /relacl/); await kapat();
  await db.exec('revoke all on olcek_tur3_yedek from baska');
  // İşlev yoksa yeniden yaratma yok.
  await db.exec('drop function public.join_tournament()');
  await assert.rejects(db.exec(geri), /yok; geri alma durdu/); await kapat();
  await db.exec(yamali.jt);
  await db.exec('revoke all on function public.join_tournament() from public, anon; grant execute on function public.join_tournament() to authenticated');

  // 23: tur3 geri alması, tur7 (ve tur4+) yedek satırı varken durur; yedek tablosu kalır.
  await assert.rejects(db.exec(read('geri_al/2026-11-05_olcek_tur3_geri.sql')), /sonraki göçlerin/); await kapat();
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur7:%'")).c, 18, 'tur3 geri alması tur7 yedeklerini silmedi');
  // 22: turnuva_sunucu_puani geri alması, düşürülecek tablolara bağlı işlev varken durur.
  await db.exec("create function public.zz_bagimli() returns int language sql as $$ select count(*)::int from tournament_match_answers $$");
  await assert.rejects(db.exec(read('geri_al/2026-10-27_turnuva_sunucu_puani_geri.sql')), /bağlı, önce uyumlu/); await kapat();
  await db.exec('drop function public.zz_bagimli()');

  // Geri alma: eski gövdeler birebir.
  await db.exec(geri);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOnce(v), tabanDef[k], 'geri alma birebir: ' + k);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur7:%'")).c, 0);
  // Beklenmeyen canlı gövde: ileri göç durur, hiçbir şey kalmaz.
  await db.exec("create or replace function public.get_my_records() returns jsonb language sql security definer set search_path to 'public' as $$ select '{}'::jsonb $$");
  await assert.rejects(uygula(), /ne bilinen canlı taban ne de/); await kapat();
  await db.exec(tabanDef.rec);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur7:%'")).c, 0);
  await uygula(); // yeniden ileri
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur7:%'")).c, 18);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOnce(v), yamali[k], 'yeniden ileri aynı gövde: ' + k);
  console.log('yedek/md5 zinciri, ya hep ya hiç, beklenmeyen gövde, geri alma ve yeniden ileri doğru');
}
console.log('TAMAM');
