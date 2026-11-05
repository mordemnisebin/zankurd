// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_w8_yonetim_local.mjs /mutlak/yol/pglite/dist/index.js
//
// 2026-11-16_w8_yonetim.sql (2.1.2 W8: yönetim bölümü). Zincir: W1 uygulanmış canlı durum.
// Her kusur ÖNCE eski (canlı taban) gövdede/şemada gösterilir, sonra göç uygulanır ve
// düzeltme kanıtlanır:
//  #10/#11 oyuncu 'approved' ekler, created_at'la hız sınırını aşar  #9 cevap anahtarı D'ye döner
//  #8 yinelenen şık                       #18 düzeltmede eski içerik günlükte yok
//  #12 şikâyet yeniden açılmaz/bildirim   #6 süresi biten askı "askıda"
//  #4/#5/#14 ödül dönemi, geçmiş seçimi, açık sonuç   #17 dönem+derece çiftlenir
//  #15/#16 otomatik ödül hata günlüğü ve telafi       #19/#21 günlük    #24 pano
//  alan9 #6 solo sayacı parçası, alan9 #18 new_today
// Sonda: yedek/md5 zinciri, ikinci uygulama no-op, ya hep ya hiç, beklenmeyen gövde, geri
// alma eski gövdeleri birebir döndürür, yeniden ileri göç çalışır.
// W8_PRINT_FINAL=1: nihai md5'leri yazdırıp çıkar (göçteki nihai sabitler için).
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
const w1 = read('2026-11-16_w1_odul_moderasyon.sql');
let forward = read('2026-11-16_w8_yonetim.sql');
const geri = read('geri_al/2026-11-16_w8_yonetim_geri.sql');
const paneli = read('2026-11-12_yonetim_paneli.sql');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const q = async (sql, args = []) => (await db.query(sql, args)).rows;
const one = async (sql, args = []) => (await q(sql, args))[0];
const defOf = async sig => (await one(`select pg_get_functiondef('${sig}'::regprocedure) d`)).d;
const kapat = async () => { try { await db.exec('rollback'); } catch (e) { /* açık işlem yok */ } };
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create (?:or replace )?function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1).replace(/^create function/i, 'create or replace function');
};
// Bir göç dosyasındaki "select pg_temp.<yama>(imza, $e$..$e$, $y$..$y$) from <durum> d where ..." bloklarını al.
const yamaBloklari = (src, yamaAd, durum, imza) => {
  const esc = imza.replace(/[()]/g, '\\$&');
  const re = new RegExp("select pg_temp\\." + yamaAd + "\\(\\s*'" + esc + "'[\\s\\S]*?from " + durum + " d\\s+where d\\.imza = '" + esc + "' and d\\.gerekli;", 'g');
  const out = src.match(re) || [];
  assert(out.length > 0, 'yama bulunamadı: ' + imza);
  return out;
};
const yamaIslevi = (src, yamaAd) => {
  const i = src.indexOf('create or replace function pg_temp.' + yamaAd);
  assert(i >= 0, yamaAd);
  return src.slice(i, src.indexOf('$yama$;', i) + 7);
};

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create table auth.identities(user_id uuid, provider text);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  set check_function_bodies = off;
  create function app_today() returns date language sql stable
    as $$ select (now() at time zone 'Europe/Istanbul')::date $$;
  create table profiles(id uuid primary key, display_name text, player_tag text, referred_by uuid,
    coins int not null default 0, xp int not null default 0,
    push_duel boolean not null default true, push_social boolean not null default true,
    avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text,
    created_at timestamptz not null default now(), updated_at timestamptz not null default now());
  create table friends(user_id uuid, friend_id uuid);
  create table blocked_users(blocker_id uuid, blocked_id uuid);
  create table categories(id uuid primary key default gen_random_uuid(), name text, slug text);
  create table questions(id uuid primary key default gen_random_uuid(), category_id uuid, prompt text,
    option_a text, option_b text, option_c text, option_d text, correct_option text, explanation text,
    difficulty int, is_approved boolean default false, review_status text, created_by uuid,
    updated_at timestamptz default now(), language_code text default 'ku-kmr', explanation_ku text,
    explanation_tr text, question_type text default 'multiple_choice', dialect text,
    quality_version int default 0, last_content_check_at timestamptz, source_title text);
  create table suggested_questions(id uuid primary key default gen_random_uuid(), user_id uuid, category text,
    prompt text, option_a text, option_b text, option_c text, option_d text, correct_option text,
    explanation text, difficulty int default 3, status text default 'pending', created_at timestamptz default now(),
    reviewed_by uuid, reviewed_at timestamptz, review_note text);
  create table question_reports(id uuid primary key default gen_random_uuid(), question_id uuid, reporter_id uuid,
    reason text, status text default 'open', created_at timestamptz default now());
  create table profile_reports(id uuid primary key default gen_random_uuid(), reporter_id uuid, reported_id uuid,
    reason text, created_at timestamptz default now(), handled_at timestamptz, unique (reporter_id, reported_id));
  create table coin_transactions(id uuid primary key default gen_random_uuid(), player_id uuid, amount int, reason text,
    created_at timestamptz default now());
  create table rooms(id uuid primary key default gen_random_uuid(), created_at timestamptz default now(),
    status text default 'lobby', finished_at timestamptz, ended_reason text, host_id uuid);
  create table room_players(room_id uuid not null, player_id uuid not null, score int not null default 0,
    streak int not null default 0, left_at timestamptz, primary key(room_id, player_id));
  create table room_invites(id uuid primary key default gen_random_uuid(), room_id uuid, invitee_id uuid,
    inviter_id uuid, status text, created_at timestamptz default now());
  create table async_duels(id uuid primary key default gen_random_uuid(), creator_id uuid not null,
    opponent_id uuid, invited_id uuid, status text default 'open', created_at timestamptz default now());
  create table tournaments(id uuid primary key default gen_random_uuid(), size int not null default 4,
    status text not null default 'open', opened_at timestamptz not null default now());
  create table tournament_entries(tournament_id uuid not null references tournaments(id), player_id uuid not null,
    display_name text not null default 'x', primary key (tournament_id, player_id));
  create table contests(id uuid primary key default gen_random_uuid(), day_key date);
  create table contest_badges(id uuid primary key default gen_random_uuid(), slug text);
  create table user_contest_badges(id uuid primary key default gen_random_uuid(), user_id uuid, badge_id uuid,
    contest_id uuid not null);
  create table verified_daily_event_results(day date not null, user_id uuid not null, correct_count int not null,
    total_count int default 10, seconds int not null, created_at timestamptz not null default clock_timestamp(),
    primary key(day, user_id));
  create table daily_event_results(day date not null, user_id uuid not null, correct_count int not null,
    total_count int default 10, seconds int not null, created_at timestamptz not null default clock_timestamp(),
    primary key(day, user_id));
  create table player_score_daily(player_id uuid not null, day date not null, score bigint not null default 0,
    streak bigint not null default 0, rooms bigint not null default 0, primary key(player_id, day));
  create table player_score_total(player_id uuid primary key, score bigint not null default 0,
    streak bigint not null default 0, rooms bigint not null default 0);
  create table push_outbox(id uuid primary key default gen_random_uuid(), to_user_id uuid, kind text, title text,
    body text, created_at timestamptz default now(), claimed_at timestamptz);
  create table olcek_tur3_yedek(ad text primary key, tanim text not null, alindi timestamptz not null default now());
  create table referral_redemptions(user_id uuid primary key references profiles(id) on delete cascade,
    referrer_id uuid references profiles(id) on delete cascade);
  create table friend_requests(id uuid primary key default gen_random_uuid(), from_user_id uuid, from_user_name text,
    to_user_id uuid, status text, created_at timestamptz not null default now(), unique (from_user_id, to_user_id));
  create table idempotent_spends(player_id uuid, idempotency_key text, amount int, reason text,
    primary key (player_id, idempotency_key));
  create function public.spend_coins(p_amount integer, p_reason text) returns jsonb language sql as
    $$ select jsonb_build_object('success', true) $$;
  create table async_duel_results(duel_id uuid not null, player_id uuid not null, correct_count int not null default 0,
    total_ms int not null default 0, finished_at timestamptz not null default now(), primary key (duel_id, player_id));
`);
// Gerçek tablolar: doğrulanmış tur (solo göçünden) ve paylaşım ödülü tablosu.
{
  const solo = read('2026-11-01_solo_daily_verified.sql');
  const i = solo.indexOf('create table if not exists public.verified_quiz_sessions');
  const j = solo.indexOf('create table if not exists public.verified_quiz_answers');
  await db.exec(solo.slice(i, j));
  const sh = read('2026-11-01_paylasim_odulu.sql');
  await db.exec(sh.slice(sh.indexOf('create table if not exists public.share_reward_claims'), sh.indexOf('create or replace function')));
}
// Haftalık lig: gerçek 11-05 göçü (cron bölümü hariç) + tur5 yaması (canlı taban).
const lig = read('2026-11-05_haftalik_lig.sql');
await db.exec(lig.slice(lig.indexOf('create table if not exists public.weekly_league_cohorts'),
  lig.indexOf('-- 5. Zamanlama')).replace(/^-- -+\n/gm, ''));
{
  const tur5 = read('2026-11-05_olcek_tur5.sql');
  await db.exec(`create temp table tur5_durum (imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null);
    insert into tur5_durum values ('public.get_my_league()', true, 0, 'x');`);
  await db.exec('begin;' + yamaIslevi(tur5, 'tur5_yama') + yamaBloklari(tur5, 'tur5_yama', 'tur5_durum', 'public.get_my_league()').join('\n') + 'commit;');
}
// Gerçek 11-12 yönetim göçü (user_is_restricted, admin_*, record_activity ...).
await db.exec(`create or replace function public.user_is_restricted(p_user uuid) returns boolean language sql stable
  security definer set search_path = public, pg_temp as $f$ select false $f$;`);
await db.exec(paneli);
// Davet: 10-15 gövdesi + tur7 yamaları (canlı taban).
{
  const sosyal = read('2026-10-15_sosyal_ve_sertlestirme.sql');
  await db.exec(fnText(sosyal, 'redeem_referral_code'));
  const tur7 = read('2026-11-06_guvenlik_tur7.sql');
  await db.exec(`create temp table tur7_durum (imza text primary key, gerekli boolean not null, sahip oid not null, nihai text not null);
    insert into tur7_durum values ('public.redeem_referral_code(text)', true, 0, 'x');`);
  await db.exec('begin;' + yamaIslevi(tur7, 'tur7_yama') + yamaBloklari(tur7, 'tur7_yama', 'tur7_durum', 'public.redeem_referral_code(text)').join('\n') + 'commit;');
}
await db.exec(fnText(read('2026-11-01_solo_daily_verified.sql'), 'claim_verified_solo_reward'));
await db.exec(fnText(read('2026-11-01_paylasim_odulu.sql'), 'claim_share_reward'));
await db.exec(fnText(read('2026-09-22_xp_and_coin_idempotency.sql'), 'spend_coins_once', '$$'));
await db.exec(fnText(lig, 'ack_my_league_result'));
await db.exec(fnText(read('2026-10-31_push_delivery_v2.sql'), 'push_delivery_v2_allowed', '$allowed$'));
// Canlı ACL'i taklit et: istemci RPC'leri anon/PUBLIC'e kapalı, authenticated açık.
for (const s of ['claim_verified_solo_reward(uuid)', 'claim_share_reward()', 'redeem_referral_code(text)',
  'spend_coins_once(integer,text,text)', 'ack_my_league_result()']) {
  await db.exec(`revoke all on function public.${s} from public, anon; grant execute on function public.${s} to authenticated`);
}
await db.exec('revoke all on function public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb) from public, anon, authenticated, service_role');


// ---- Canlı durum: W1 uygulanmış (applied.md ✅) ----
await db.exec(w1);
// Oneri hız sınırı (2026-11-01 ✅) ve kategoriler.
await db.exec(read('2026-11-01_oneri_siniri.sql'));

const IMZA = {
  rev: 'public.admin_review_suggestion(uuid,text,text,jsonb)',
  fix: 'public.admin_fix_question(uuid,text,text[],integer,text)',
  cand: 'public.admin_list_reward_candidates(text,text)',
  grant: 'public.admin_grant_reward(text,text,uuid,integer,text)',
  auto: 'public._admin_auto_grant(text,text)',
  run: 'public.admin_run_auto_rewards()',
  reps: 'public.admin_list_user_reports(integer)',
  stats: 'public.admin_get_stats()',
  audit: 'public.admin_list_audit(integer)',
  notify: 'public.admin_set_notify_pref(text,boolean)',
  rec: 'public.record_activity(boolean)',
};
const tabanDef = {};
for (const [k, v] of Object.entries(IMZA)) tabanDef[k] = await defOf(v);
for (const [k, v] of Object.entries(IMZA)) {
  assert(forward.includes("'" + v + "', '" + md5(tabanDef[k]) + "'"), 'göçteki taban md5 = zincirden türeyen gövde: ' + k + ' ' + md5(tabanDef[k]));
}
if (process.env.W8_PRINT_FINAL) {
  const f = forward.replace('if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then', 'if false then');
  await db.exec(f);
  const out = {};
  for (const [k, v] of Object.entries(IMZA)) out[v] = md5(await defOf(v));
  console.log(JSON.stringify(out, null, 1));
  process.exit(0);
}
const uygula = () => db.exec(forward);

for (let i = 1; i <= 20; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
  await db.query('insert into profiles(id, display_name, player_tag) values ($1, $2, $3)', [U(i), 'U' + i, 'T' + String(i).padStart(3, '0')]);
}
await db.query('insert into admins(user_id) values ($1)', [U(4)]);
await db.query("insert into categories(name, slug) values ('Tarih', 'tarih')");
const gun = async n => (await one('select (public.app_today() + $1::int)::text d', [n])).d;
const as0 = () => as(0);
const adm = async fn => { await as(4); try { return await fn(); } finally { await as(0); } };
const coinsOf = async u => Number((await one('select coins from profiles where id = $1', [U(u)])).coins);
const sonuc = async (day, user, correct, secs) => db.query(
  'insert into verified_daily_event_results(day, user_id, correct_count, seconds) values ($1, $2, $3, $4)', [day, U(user), correct, secs]);
const suggest = async (user, o = {}) => {
  await as(user);
  try {
    return (await one(`insert into suggested_questions(user_id, category, prompt, option_a, option_b, option_c, option_d,
        correct_option, explanation, status, reviewed_by, created_at)
      values ($1, 'Tarih', $2, $3, $4, $5, $6, $7, 'a', $8, $9, coalesce($10::timestamptz, now())) returning *`,
      [U(user), o.prompt ?? 'Soru ' + Math.random(), ...(o.opts ?? ['a', 'b', 'c', 'd']), o.correct ?? 'A',
       o.status ?? 'pending', o.reviewedBy ?? null, o.created ?? null]));
  } finally { await as(0); }
};
const review = (id, decision = 'approve', edits = null) => adm(async () =>
  (await one('select public.admin_review_suggestion($1, $2, null, $3::jsonb) r', [id, decision, edits ? JSON.stringify(edits) : null])).r);

// ============ ÖN: kusurlar eski (canlı taban) gövdelerde / şemada ============
// #10 oyuncu kendi önerisini 'approved' ekler; #11 created_at'ı geçmişe çekip hız sınırını aşar
{
  const s = await suggest(6, {status: 'approved', reviewedBy: U(4), created: '2026-01-01T00:00:00Z'});
  assert.equal(s.status, 'approved', 'TABAN KUSURU: oyuncu status=approved ekleyebilir');
  assert.equal(s.reviewed_by, U(4));
  for (let i = 0; i < 14; i++) await suggest(8, {created: '2026-01-01T00:00:00Z'});
  assert.equal((await one('select count(*)::int c from suggested_questions where user_id = $1', [U(8)])).c, 14,
    'TABAN KUSURU: created_at geçmiş verilince 24 saatlik 10 öneri sınırı hiç işlemez');
}
// #9 geçersiz cevap anahtarı sessizce D olur; #8 çift şıklı öneri onaylanır
let sZ, sDup;
{
  sZ = await suggest(9, {correct: 'Z', prompt: 'Z soru'});
  const r = await review(sZ.id);
  const q = await one('select correct_option from questions where id = $1', [r.question_id]);
  assert.equal(q.correct_option, 'D', 'TABAN KUSURU: geçersiz cevap anahtarı sessizce D');
  sDup = await suggest(9, {opts: ['x', 'x', 'y', 'z'], prompt: 'Cift sik soru'});
  const r2 = await review(sDup.id);
  assert((await one('select 1 ok from questions where id = $1', [r2.question_id])).ok, 'TABAN KUSURU: aynı şıklı öneri onaylanır');
  // bu satır geri alma dönüşünden sonra da bekçiyi sınamak için bekleyen geçersiz anahtar
  await suggest(9, {correct: 'Q', prompt: 'Bekleyen Q'});
}
// #8 / #18 düzeltme: yinelenen şık geçer, eski içerik günlüğe yazılmaz
let qFix;
{
  qFix = (await one(`insert into questions(category_id, prompt, option_a, option_b, option_c, option_d, correct_option, is_approved)
    select id, 'Eski soru', 'A1', 'B1', 'C1', 'D1', 'B', true from categories limit 1 returning id`)).id;
  await adm(() => db.query('select public.admin_fix_question($1, $2, $3::text[], 2, null)', [qFix, 'Yeni soru', ['p', 'p', 'q', 'r']]));
  const lg = await one("select detail from admin_audit_log where action = 'question_fix' order by id desc limit 1");
  assert.equal(lg.detail.before, undefined, 'TABAN KUSURU: eski içerik günlükte yok');
  assert.equal((await one('select option_a, option_b from questions where id = $1', [qFix])).option_b, 'p', 'TABAN KUSURU: yinelenen şık düzeltmesi geçer');
}
// #12 sonuçlanmış şikâyet yeniden gönderilince açılmaz, bildirim yok
const yenidenBildir = u => db.query(`insert into profile_reports(reporter_id, reported_id, reason) values ($1, $2, 'tekrar')
  on conflict (reporter_id, reported_id) do update set reason = excluded.reason, created_at = now()`, [U(1), U(u)]);
const outbox = async () => Number((await one("select count(*)::int c from push_outbox where kind = 'admin_report'")).c);
{
  await db.query("insert into profile_reports(reporter_id, reported_id, reason, created_at) values ($1, $2, 'ilk', now() - interval '2 days')", [U(1), U(2)]);
  await adm(() => db.query("select public.admin_moderate_user($1, 'warn', null, 'n')", [U(2)]));
  assert((await one('select handled_at from profile_reports where reported_id = $1', [U(2)])).handled_at, 'sonuçlandı');
  const once = await outbox();
  await yenidenBildir(2);
  assert((await one('select handled_at from profile_reports where reported_id = $1', [U(2)])).handled_at,
    'TABAN KUSURU: yeniden gönderilen şikâyet kapalı kalır');
  assert.equal(await outbox(), once, 'TABAN KUSURU: bildirim gitmez');
}
// #6 süresi dolmuş askı panelde hâlâ "suspended"
const rapor = async () => (await adm(async () => (await one('select public.admin_list_user_reports(50) r')).r));
{
  await db.query("insert into profile_reports(reporter_id, reported_id, reason) values ($1, $2, 'x')", [U(7), U(6)]);
  await adm(() => db.query("select public.admin_moderate_user($1, 'suspend', 1, 'n')", [U(6)]));
  await db.query("update user_moderation set until = now() - interval '1 hour' where user_id = $1", [U(6)]);
  const row = (await rapor()).find(r => r.user_id === U(6));
  assert.equal(row?.state, 'suspended', 'TABAN KUSURU: süresi bitmiş askı "suspended" görünür');
}
// #4 bugünkü (bitmemiş) dönem ödülü verilebilir; #17 dönem+derece çiftlenir
await sonuc(await gun(0), 10, 9, 30); await sonuc(await gun(0), 11, 8, 30);
{
  const r = await adm(async () => (await one("select public.admin_grant_reward('daily', null, $1, 100) r", [U(10)])).r);
  assert.equal(r.granted, true, 'TABAN KUSURU: bitmemiş günün ödülü geri alınamaz verilir');
}
const D17 = await gun(-15);
await sonuc(D17, 17, 9, 10); await sonuc(D17, 18, 8, 10); await sonuc(D17, 19, 7, 10);
{
  await adm(() => db.query("select public.admin_grant_reward('daily', $1, $2, 50)", [D17, U(17)]));
  await adm(() => db.query("select public.admin_moderate_user($1, 'block', null, 'n')", [U(17)]));
  const r = await adm(async () => (await one("select public.admin_grant_reward('daily', $1, $2, 50) r", [D17, U(18)])).r);
  assert.equal(r.granted, true);
  assert.equal(Number((await one("select count(*)::int c from admin_reward_grants where period_key = $1 and rank = 1", [D17])).c), 2,
    'TABAN KUSURU: aynı dönemde iki kişiye 1. derece ödülü');
  // Göç ön denetimi: yinelenen derece varken kurulamaz.
  await assert.rejects(uygula(), /aynı dönem\+derece için birden çok ödül/); await kapat();
  await db.query("delete from admin_reward_grants where period_key = $1 and user_id = $2", [D17, U(18)]);
}
// #15 / #16 otomatik ödül: kişi hatası sessiz, geç kalan günler telafi edilmez
for (let o = -10; o <= -1; o++) {
  for (const [u, c] of [[11, 9], [12, 8], [13, 7]]) await sonuc(await gun(o), u, c, 20 + u);
}
await db.query('delete from verified_daily_event_results where day = $1 and user_id = $2', [await gun(-2), U(11)]);
// hayalet oyuncu: profili yok -> jeton yazılamaz (user_not_found), 1. derece
await sonuc(await gun(-2), 99, 10, 5);
for (let o = -28; o <= -1; o++) {
  for (const u of [14, 15, 16]) await db.query('insert into player_score_daily(player_id, day, score) values ($1, public.app_today() + $2::int, $3)', [U(u), o, 100 + u]);
}
await db.query("insert into admin_settings(key, value) values ('auto_reward', 'true'::jsonb), ('auto_reward_since', to_jsonb(($1)::text))", [await gun(-30)]);
const otoSay = async kind => Number((await one("select count(*)::int c from admin_reward_grants where source = 'auto' and period_kind = $1", [kind])).c);
const koş = async () => (await one('select public.admin_run_auto_rewards() r')).r;
let tabanDaily, tabanWeekly;
{
  const g = await koş();
  tabanDaily = await otoSay('daily'); tabanWeekly = await otoSay('weekly');
  assert.equal(tabanDaily, 8, 'TABAN: yalnız son 3 gün (-3,-2,-1; hayalet 1. derece düşer): ' + JSON.stringify(g));
  assert.equal(tabanWeekly, 6, 'TABAN: yalnız son 2 hafta');
  assert.equal((await one("select count(*)::int c from admin_audit_log where action = 'reward_auto_error'")).c, 0,
    'TABAN KUSURU: kişi hatası hiçbir iz bırakmaz');
}
// #19 / #21 / #24 / alan9 #6
{
  await adm(() => db.query("select public.admin_set_notify_pref('report', false)"));
  assert.equal((await one("select count(*)::int c from admin_audit_log where action = 'notify_pref_set'")).c, 0, 'TABAN KUSURU: tercih günlüğe yazılmaz');
  const a = await adm(async () => (await one('select public.admin_list_audit(5) r')).r);
  assert.equal(a[0].id, undefined, 'TABAN KUSURU: id/admin_id yok');
  await db.exec('delete from admin_notify_prefs'); // sonraki bildirim denetimleri için varsayılan açık
}
await db.query('insert into daily_event_results(day, user_id, correct_count, seconds) values ($1, $2, 5, 5)', [await gun(-2), U(14)]);
const bugunSay = async () => Number((await adm(async () => (await one('select public.admin_get_stats() r')).r)).mode_usage.contest);
const vSay = async () => Number((await one('select count(*)::int c from verified_daily_event_results where day > public.app_today() - 7')).c);
{
  assert.equal(await bugunSay(), (await vSay()) + 1, 'TABAN KUSURU: geçiş gününde iki tablo çift sayılır');
}
const enBuyukParca = async () => Number((await one("select coalesce(max(shard), 0) m from usage_mode_counter where mode = 'solo'")).m);
for (let u = 1; u <= 10; u++) {
  await as(u);
  for (let i = 0; i < 30; i++) await db.query('select public.record_activity(true)');
  await as(0);
}
assert((await enBuyukParca()) <= 7, 'TABAN: 8 parça');

// ============================ GÖÇ ============================
await uygula();

// ============ SON: her kusur kapanmış ============
// #10 / #11
{
  const s = await suggest(6, {status: 'approved', reviewedBy: U(4), created: '2026-01-01T00:00:00Z'});
  assert.equal(s.status, 'pending', '#10 status sunucuda pending');
  assert.equal(s.reviewed_by, null);
  assert((Date.now() - new Date(s.created_at).getTime()) < 60000, '#11 created_at sunucu saati');
  let ret = 0;
  for (let i = 0; i < 12; i++) {
    try { await suggest(12, {created: '2026-01-01T00:00:00Z'}); } catch (e) { assert(/suggestion_rate_limited/.test(e.message)); ret++; }
  }
  assert.equal(ret, 2, '#11 geçmiş created_at ile 10 sınırı aşılamaz (12 denemeden 2 ret)');
  // service_role / SQL (auth.uid() yok) dokunulmaz
  const sv = await one("insert into suggested_questions(user_id, prompt, status) values ($1, 'servis', 'approved') returning status", [U(12)]);
  assert.equal(sv.status, 'approved');
}
// #9
{
  await assert.rejects(suggest(13, {correct: 'Q'}), /correct_option_w8_check/); await kapat();
  const kucuk = await suggest(13, {correct: 'b'});
  assert.equal(kucuk.correct_option, 'b');
  assert.equal(((await review(kucuk.id)).status), 'approved', 'küçük harf geçerli');
  const bekleyen = await one("select id from suggested_questions where prompt = 'Bekleyen Q'");
  await assert.rejects(review(bekleyen.id), /bad_edits/); await kapat();
  assert.equal((await one('select convalidated from pg_constraint where conname = $1', ['suggested_questions_correct_option_w8_check'])).convalidated, false,
    'eski bozuk satır var: NOT VALID kaldı');
  assert.equal((await review(bekleyen.id, 'approve', {correct: 2})).status, 'approved', 'düzeltmeyle onaylanır');
}
// #8
{
  const d = await suggest(13, {opts: ['x', ' X ', 'y', 'z'], prompt: 'Cift 2'});
  await assert.rejects(review(d.id), /bad_edits/); await kapat();
  assert.equal((await review(d.id, 'approve', {options: ['x', 'w', 'y', 'z']})).status, 'approved', 'düzeltilmiş şıkla onay');
  await assert.rejects(adm(() => db.query('select public.admin_fix_question($1, $2, $3::text[], 2, null)', [qFix, 'Y', ['p', 'P', 'q', 'r']])), /bad_edits/); await kapat();
}
// #18
{
  await adm(() => db.query('select public.admin_fix_question($1, $2, $3::text[], 1, null)', [qFix, 'Son soru', ['m', 'n', 'o', 'p']]));
  const lg = await one("select detail from admin_audit_log where action = 'question_fix' order by id desc limit 1");
  assert.equal(lg.detail.before.prompt, 'Yeni soru');
  assert.deepEqual(lg.detail.before.options, ['p', 'p', 'q', 'r']);
  assert.equal(lg.detail.before.correct, 'C');
  const e = await suggest(13, {prompt: 'Duzeltilecek', opts: ['1', '2', '3', '4']});
  await review(e.id, 'approve', {prompt: 'Duzeltilmis', options: ['1', '2', '3', '5']});
  const lg2 = await one("select detail from admin_audit_log where action = 'suggestion_approve' order by id desc limit 1");
  assert.equal(lg2.detail.original.prompt, 'Duzeltilecek');
  assert.deepEqual(lg2.detail.original.options, ['1', '2', '3', '4']);
}
// #12
{
  const once = await outbox();
  await yenidenBildir(2);
  assert.equal((await one('select handled_at from profile_reports where reported_id = $1', [U(2)])).handled_at, null, '#12 yeniden açıldı');
  assert.equal(await outbox(), once + 1, '#12 yöneticiye bildirim gitti');
  await yenidenBildir(2);
  assert.equal(await outbox(), once + 1, 'açık şikâyetin tekrarı bildirim yağdırmaz');
  // moderasyon yazısı (handled_at değişir) yeniden açma sayılmaz
  await adm(() => db.query("select public.admin_moderate_user($1, 'block', null, 'n')", [U(2)]));
  assert((await one('select handled_at from profile_reports where reported_id = $1', [U(2)])).handled_at);
  assert.equal(await outbox(), once + 1);
  await adm(() => db.query("select public.admin_moderate_user($1, 'lift', null, null)", [U(2)]));
}
// #6
{
  const row = (await rapor()).find(r => r.user_id === U(6));
  assert.equal(row, undefined, '#6 süresi bitmiş askı listede yok');
  await db.query("update user_moderation set until = now() + interval '1 day' where user_id = $1", [U(6)]);
  assert.equal((await rapor()).find(r => r.user_id === U(6)).state, 'suspended', 'süren askı görünür');
  await adm(() => db.query("select public.admin_moderate_user($1, 'lift', null, null)", [U(6)]));
}
// #4 / #5 / #14 / #17
{
  const rpc = (sql, a) => adm(async () => (await one(sql, a)).r);
  await assert.rejects(rpc("select public.admin_grant_reward('daily', null, $1, 100) r", [U(10)]), /period_not_finished/); await kapat();
  await assert.rejects(rpc("select public.admin_list_reward_candidates('daily', $1) r", [await gun(0)]), /period_not_finished/); await kapat();
  await assert.rejects(rpc("select public.admin_list_reward_candidates('weekly', $1) r", [await gun(0)]), /period_not_finished/); await kapat();
  const c = await rpc("select public.admin_list_reward_candidates('daily', null) r");
  assert.equal(c.period_key, await gun(-1), 'varsayılan = son tamamlanan dönem');
  assert.equal(c.prev_key, await gun(-2));
  assert.equal(c.next_key, null);
  assert.equal(c.period_finished, true);
  const c2 = await rpc("select public.admin_list_reward_candidates('daily', $1) r", [await gun(-4)]);
  assert.equal(c2.next_key, await gun(-3));
  const hw = await rpc("select public.admin_list_reward_candidates('weekly', null) r");
  assert.equal(hw.prev_key, (await one("select (($1::date) - 7)::text d", [hw.period_key])).d);
  assert.equal(hw.next_key, null);
  // Geçmiş dönem seçimi + #14 açık nedenler
  const D5 = await gun(-40);
  await sonuc(D5, 13, 9, 10); await sonuc(D5, 14, 8, 10); await sonuc(D5, 15, 7, 10);
  const g1 = await rpc("select public.admin_grant_reward('daily', $1, $2, 100) r", [D5, U(13)]);
  assert.equal(g1.granted, true); assert.equal(g1.rank, 1);
  const g2 = await rpc("select public.admin_grant_reward('daily', $1, $2, 100) r", [D5, U(13)]);
  assert.deepEqual([g2.granted, g2.reason], [false, 'already_rewarded']);
  // #17: 1. derece ödüllenmiş, sahibi kısıtlanınca sıradaki 1. olur: aynı derece iki kez verilmez
  await adm(() => db.query("select public.admin_moderate_user($1, 'block', null, 'n')", [U(13)]));
  const g3 = await rpc("select public.admin_grant_reward('daily', $1, $2, 100) r", [D5, U(14)]);
  assert.deepEqual([g3.granted, g3.reason], [false, 'rank_already_rewarded'], '#17');
  assert.equal(Number((await one('select count(*)::int c from admin_reward_grants where period_key = $1 and rank = 1', [D5])).c), 1);
  await adm(() => db.query("select public.admin_moderate_user($1, 'lift', null, null)", [U(13)]));
  // veritabanı düzeyi güvence
  await assert.rejects(db.query("insert into admin_reward_grants(period_kind, period_key, user_id, rank, coins, source) values ('daily', $1, $2, 1, 0, 'auto')", [D5, U(20)]), /rank_uidx/); await kapat();
}
// #15 / #16 telafi + hata günlüğü
{
  const g = await koş();
  const gunlukSon = await otoSay('daily');
  assert(gunlukSon > tabanDaily, '#16 geç kalan günler telafi edildi: ' + tabanDaily + ' -> ' + gunlukSon);
  const hafSon = await otoSay('weekly');
  assert(hafSon >= 9, '#16 geç kalan haftalar telafi edildi (' + hafSon + ')');
  const hata = await q("select detail from admin_audit_log where action = 'reward_auto_error'");
  assert(hata.length >= 1 && hata.every(h => h.detail.sqlstate && h.detail.kind), '#15 kişi hatası günlükte: ' + JSON.stringify(hata));
  const m = await q("select key, value #>> '{}' v from admin_settings where key like 'auto_reward_done_%' order by key");
  assert.deepEqual(m.map(x => x.key), ['auto_reward_done_daily', 'auto_reward_done_weekly']);
  assert.equal(m[0].v, await gun(-1));
  // ikinci çalıştırma: yeni iş yok, çift ödeme yok
  const hataSay = hata.length;
  const g2 = await koş();
  assert.equal(g2.granted, 0, 'ilerleme işaretinden sonra yeni dönem yok');
  assert.equal((await q("select 1 from admin_audit_log where action = 'reward_auto_error'")).length, hataSay, 'tekrar hata günlüğü şişmez');
  // her (dönem, derece) tek
  assert.equal((await q('select 1 from admin_reward_grants group by period_kind, period_key, rank having count(*) > 1')).length, 0);
  // açıldığı günden önceki dönem ödüllenmez
  assert.equal((await q("select 1 from admin_reward_grants where source = 'auto' and period_kind = 'daily' and period_key < $1", [await gun(-30)])).length, 0);
  // yeni gün: işaretler ilerler (zaman yolculuğu: since'i geri çek, bir gün eklenmiş gibi)
  await sonuc(await gun(0), 12, 10, 1);
  await db.query("update admin_settings set value = to_jsonb(($1)::text) where key = 'auto_reward_done_daily'", [await gun(-2)]);
  const g3 = await koş();
  assert.equal((await one("select value #>> '{}' v from admin_settings where key = 'auto_reward_done_daily'")).v, await gun(-1), 'işaret geri alınıp yeniden ilerletildi');
  assert.equal(g3.granted, 0, 'zaten verilmiş dönem tekrar ödenmez');
}
// #19 / #21
{
  await adm(() => db.query("select public.admin_set_notify_pref('report', true)"));
  const l = await one("select detail, admin_id from admin_audit_log where action = 'notify_pref_set'");
  assert.equal(l.detail.enabled, true); assert.equal(l.admin_id, U(4));
  const a = await adm(async () => (await one('select public.admin_list_audit(3) r')).r);
  assert.equal(a.length, 3); assert(a[0].id !== undefined && 'admin_id' in a[0]);
  await db.exec("insert into admin_audit_log(admin_id, action, target_type, detail) select null, 'x', 'x', '{}' from generate_series(1, 150)");
  const p1 = await adm(async () => (await one('select public.admin_list_audit_page(50, null) r')).r);
  assert.equal(p1.length, 50);
  const p2 = await adm(async () => (await one('select public.admin_list_audit_page(50, $1) r', [p1[49].id])).r);
  assert(p2.length > 0 && Number(p2[0].id) < Number(p1[49].id), 'sayfalama eski kayıtlara iner');
  const ids = [...p1, ...p2].map(x => String(x.id));
  assert.equal(new Set(ids).size, ids.length, 'sayfalar çakışmaz');
  await as(5);
  await assert.rejects(db.query('select public.admin_list_audit_page(10, null)'), /admin_required/); await kapat();
  await as(0);
}
// #24 / alan9 #18
{
  assert.equal(await bugunSay(), await vSay(), '#24 geçişte iki tablo çift sayılmaz');
  const st = await adm(async () => (await one('select public.admin_get_stats() r')).r);
  assert.equal(Number(st.new_today), 20, 'new_today = bugün açılan hesaplar');
  await db.query("update profiles set created_at = now() - interval '30 hours' where id = $1", [U(1)]);
  const st2 = await adm(async () => (await one('select public.admin_get_stats() r')).r);
  assert.equal(Number(st2.new_today), 19, 'dünkü hesap new_today dışında');
  await db.query('update profiles set created_at = now() where id = $1', [U(1)]);
}
// alan9 #6 solo sayacı 64 parça (W1 günlük sınırı korunur)
{
  for (let u = 11; u <= 20; u++) {
    await as(u);
    for (let i = 0; i < 35; i++) await db.query('select public.record_activity(true)');
    await as(0);
  }
  assert((await enBuyukParca()) > 7, 'shard 8 üstüne dağılır');
  assert((await enBuyukParca()) <= 63);
  const s = Number((await one("select sum(n)::int s from usage_mode_counter where mode = 'solo'")).s);
  assert.equal(s, 10 * 30 + 10 * 30, 'W1 günlük 30 sınırı sürüyor (35 çağrıdan 30 sayılır)');
  assert((await defOf(IMZA.rec)).includes('solo_n'), 'W1 gövdesi korunmuş');
}

// ======================= Güvenlik / yedek / geri alma =======================
{
  for (const v of Object.values(IMZA)) {
    const p = await one(`select prosecdef, proconfig, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('public', p.oid, 'execute') b from pg_proc p where p.oid = '${v}'::regprocedure`);
    assert(p.proconfig && p.prosecdef && !p.a && !p.b, v);
  }
  for (const s of ['public.admin_list_audit_page(integer,bigint)', 'public._admin_reward_last_key(text)', 'public.w8_force_suggestion_defaults()', 'public.w8_reopen_profile_report()']) {
    const p = await one(`select prosecdef, proconfig, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('public', p.oid, 'execute') b, has_function_privilege('authenticated', p.oid, 'execute') c from pg_proc p where p.oid = '${s}'::regprocedure`);
    assert(p.proconfig && p.prosecdef && !p.a && !p.b, s);
    assert.equal(p.c, s.includes('audit_page'), s + ' authenticated durumu');
  }
  const ya = await q("select ad, tanim from olcek_tur3_yedek where ad like 'w8:%'");
  assert.equal(ya.length, 11);
  for (const y of ya) assert(/-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$/.test(y.tanim), 'yedek iki md5 taşır: ' + y.ad);
  const yamali = {};
  for (const [k, v] of Object.entries(IMZA)) yamali[k] = await defOf(v);
  const yedekler = await q('select * from olcek_tur3_yedek');
  // anon hiçbir yönetici RPC'sini çağıramaz
  await db.exec('set role anon');
  await assert.rejects(db.query('select public.admin_list_audit_page(10, null)'), /permission denied/); await kapat();
  await db.exec('reset role');
  // İkinci uygulama no-op (yedek ve gövdeler değişmez).
  await uygula();
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), yamali[k], 'ikinci uygulama no-op: ' + k);
  assert.equal((await q("select 1 from olcek_tur3_yedek where ad like 'w8:%'")).length, 11);

  // Ya hep ya hiç: tek yedek eksik -> hiçbir şey dönmez.
  await db.exec("delete from olcek_tur3_yedek where ad = 'w8:public.record_activity(boolean)'");
  await assert.rejects(db.exec(geri), /yedek satırı yok/); await kapat();
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), yamali[k], 'eksik yedekte ' + k + ' dönmedi');
  await db.query("insert into olcek_tur3_yedek select * from unnest($1::text[], $2::text[], $3::timestamptz[]) on conflict do nothing",
    [yedekler.map(y => y.ad), yedekler.map(y => y.tanim), yedekler.map(y => y.alindi)]);
  // Bozuk md5 zinciri.
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:', '-- md5:0') where ad like 'w8:%'");
  await assert.rejects(db.exec(geri), /bozuk/); await kapat();
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:0', '-- md5:') where ad like 'w8:%'");
  // Uygulanmış dalda yedek yoksa ileri göç durur.
  const kopya = await q("select * from olcek_tur3_yedek where ad like 'w8:%'");
  await db.exec("delete from olcek_tur3_yedek where ad like 'w8:%'");
  await assert.rejects(uygula(), /yedek satırı\/md5 zinciri sağlam değil/); await kapat();
  for (const y of kopya) await db.query('insert into olcek_tur3_yedek values ($1,$2,$3)', [y.ad, y.tanim, y.alindi]);
  // Göçten sonra gövde değişmişse geri alma durur.
  await db.exec(yamali.notify.replace("raise exception 'bad_kind' using errcode = '22023';", "raise exception 'bad_kind' using errcode = '22023'; /*x*/"));
  await assert.rejects(db.exec(geri), /canlı gövdesi göçten sonra değişmiş/); await kapat();
  await db.exec(yamali.notify);
  // Sızdıran yedek ACL'i: ileri göç durur.
  await db.exec('create role baska; grant select on olcek_tur3_yedek to baska');
  await assert.rejects(uygula(), /relacl/); await kapat();
  await db.exec('revoke all on olcek_tur3_yedek from baska');
  // İşlev yoksa yeniden yaratma yok.
  await db.exec('drop function public.admin_set_notify_pref(text, boolean)');
  await assert.rejects(db.exec(geri), /yok; geri alma durdu/); await kapat();
  await db.exec(yamali.notify);
  await db.exec('revoke all on function public.admin_set_notify_pref(text, boolean) from public, anon, authenticated; grant execute on function public.admin_set_notify_pref(text, boolean) to authenticated');

  // Geri alma: eski gövdeler birebir; yeni nesneler silinir.
  await db.exec(geri);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), tabanDef[k], 'geri alma birebir: ' + k);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w8:%'")).c, 0);
  for (const s of ['public.admin_list_audit_page(integer,bigint)', 'public._admin_reward_last_key(text)', 'public.w8_force_suggestion_defaults()', 'public.w8_reopen_profile_report()'])
    assert.equal((await one(`select to_regprocedure('${s}') p`)).p, null, s + ' silindi');
  assert.equal((await one("select count(*)::int c from pg_trigger where tgname in ('suggested_questions_00_force_defaults','trg_w8_profile_report_reopen','trg_w8_profile_report_reopen_push')")).c, 0);
  assert.equal((await one("select count(*)::int c from pg_indexes where indexname = 'admin_reward_grants_rank_uidx'")).c, 0);
  // eski davranış geri geldi: oyuncu yine approved ekleyebilir
  assert.equal((await suggest(14, {status: 'approved'})).status, 'approved');
  // Beklenmeyen canlı gövde: ileri göç durur, hiçbir şey kalmaz.
  await db.exec("create or replace function public.admin_set_notify_pref(p_kind text, p_enabled boolean) returns void language sql security definer set search_path to 'public' as $$ select 1 $$");
  await assert.rejects(uygula(), /ne bilinen canlı taban ne de/); await kapat();
  await db.exec(tabanDef.notify);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w8:%'")).c, 0);
  await uygula(); // yeniden ileri
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w8:%'")).c, 11);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), yamali[k], 'yeniden ileri aynı gövde: ' + k);
  console.log('yedek/md5 zinciri, ya hep ya hiç, beklenmeyen gövde, geri alma ve yeniden ileri doğru');
}
console.log('TAMAM');
