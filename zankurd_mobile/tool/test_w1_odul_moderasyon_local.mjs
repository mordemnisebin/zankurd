// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_w1_odul_moderasyon_local.mjs /mutlak/yol/pglite/dist/index.js
//
// 2026-11-16_w1_odul_moderasyon.sql (2.1.2 W1: ödül / moderasyon / bildirim claim).
// Her kusur ÖNCE eski (canlı taban) gövdede gösterilir, sonra göç uygulanır ve düzeltme
// kanıtlanır:
//  #2  boş / tek soruluk solo turdan taban jeton   #11 davet ödülünün "oynadı" kanıtı
//  #1  paylaşım ödülü etkinliksiz                   #5  kısıtlı hesap: solo, paylaşım, davet,
//  lig, turnuva                                     #6  katkı ödülü tekrarında çift ödeme
//  #7  spend_coins_once anahtar/tutar uyuşmazlığı   #10 record_activity sayacı sınırsız
//  alan2 #10/#11/#12 lig (kısıtlı, ack, telafi kapanışı)
//  alan4 #8/#14/#22 push_delivery_v2_allowed        alan4 #15 admin_enqueue_push uyarısı
// Sonda: yedek/md5 zinciri, ikinci uygulama no-op, ya hep ya hiç, beklenmeyen gövde, geri
// alma eski gövdeleri birebir döndürür, yeniden ileri göç çalışır.
// W1_PRINT_FINAL=1: nihai md5'leri yazdırıp çıkar (göçteki NIHAI_* sabitleri için).
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
let forward = read('2026-11-16_w1_odul_moderasyon.sql');
const geri = read('geri_al/2026-11-16_w1_odul_moderasyon_geri.sql');
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
    reason text, created_at timestamptz default now(), handled_at timestamptz);
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

// Göçteki taban md5'leri: zincirden yeniden kurulan gövdelerle BİREBİR aynı olmalı.
const IMZA = {
  solo: 'public.claim_verified_solo_reward(uuid)', share: 'public.claim_share_reward()',
  ref: 'public.redeem_referral_code(text)', spend: 'public.spend_coins_once(integer,text,text)',
  rec: 'public.record_activity(boolean)', adm: 'public.admin_reward_contributor(uuid,integer,text)',
  mod: 'public.admin_moderate_user(uuid,text,integer,text)', lg: 'public.get_my_league()',
  ack: 'public.ack_my_league_result()',
  allowed: 'public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)', enq: 'public.admin_enqueue_push()',
};
const tabanDef = {};
for (const [k, v] of Object.entries(IMZA)) tabanDef[k] = await defOf(v);
for (const [k, v] of Object.entries(IMZA)) {
  assert(forward.includes("'" + v + "', '" + md5(tabanDef[k]) + "'"), 'göçteki taban md5 = zincirden türeyen gövde: ' + k + ' ' + md5(tabanDef[k]));
}
if (process.env.W1_PRINT_FINAL) {
  const f = forward.replace('if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then', 'if false then');
  await db.exec(f);
  const out = {};
  for (const [k, v] of Object.entries(IMZA)) out[k] = md5(await defOf(v));
  console.log(JSON.stringify(out));
  process.exit(0);
}
const uygula = () => db.exec(forward);

// ---- Kullanıcılar: 1 oyuncu, 2 davet eden, 3 kısıtlı, 4 yönetici, 5 katkıcı, 6.. diğer ----
for (let i = 1; i <= 20; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
  await db.query('insert into profiles(id, display_name, player_tag) values ($1, $2, $3)', [U(i), 'U' + i, 'T' + String(i).padStart(3, '0')]);
  await db.query("insert into auth.identities values ($1, 'google')", [U(i)]);
}
await db.query('insert into admins(user_id) values ($1)', [U(4)]);
await db.query('insert into suggested_questions(user_id, prompt) values ($1, $2)', [U(5), 'S']);
const ok = async (n, fn) => { await as(n); try { return await fn(); } finally { await as(0); } };
const R = n => '30000000-0000-0000-0000-' + String(n).padStart(12, '0');
let seq = 0;
// Doğrulanmış tur: n soru, c doğru, süre s sn (tamamlanmış).
const tur = async (user, n, c, s) => {
  const id = '50000000-0000-0000-0000-' + String(++seq).padStart(12, '0');
  const ids = Array.from({length: n}, (_, i) => '70000000-0000-0000-0000-' + String(seq * 100 + i).padStart(12, '0'));
  await db.query(`insert into verified_quiz_sessions(user_id, client_round_id, is_daily, question_ids, correct_options,
      answered_count, correct_count, current_streak, best_streak, started_at, completed_at)
    values ($1, $2, false, $3, $4, $5, $6, $6, $6, now() - make_interval(secs => $7 + 5), now() - interval '5 seconds')`,
    [U(user), id, ids, ids.map(() => 'A'), n, c, s]);
  return id;
};
const claimSolo = (user, id) => ok(user, async () => (await one('select public.claim_verified_solo_reward($1) r', [id])).r);
const kisitla = async u => { await as(4); await db.query("select public.admin_moderate_user($1, 'block', null, 't')", [U(u)]); await as(0); };
const rows = async (sql, a = []) => (await q(sql, a));

// ====================== ÖN: kusurlar eski (canlı taban) gövdelerde ======================
// #2 boş / tek soruluk solo tur
{
  const bos = await claimSolo(1, await tur(1, 1, 0, 3));
  assert.equal(bos.amount, 4, 'TABAN KUSURU: tek soruluk, sıfır doğru tur 4 jeton verir');
  const bos10 = await claimSolo(1, await tur(1, 10, 0, 1));
  assert.equal(bos10.amount, 4, 'TABAN KUSURU: 10 soru sıfır doğru 1 sn tur 4 jeton verir');
  // #11 aynı sahte tur davet ödülünün "oynadı" kanıtı olur
  await as(7);
  const r = (await one('select public.redeem_referral_code($1) r', ['T002'])).r;
  await as(0);
  assert.equal(r.success, false, 'sahte tur olmadan: not_active');
  const sahte = await claimSolo(7, await tur(7, 1, 0, 3));
  assert.equal(sahte.amount, 4);
  await as(7);
  const r2 = (await one('select public.redeem_referral_code($1) r', ['T002'])).r;
  await as(0);
  assert.equal(r2.success, true, 'TABAN KUSURU: tek soruluk boş tur davet ödülünü açar (100 jeton)');
}
// #1 paylaşım ödülü etkinliksiz
{
  await as(8);
  const r = await one('select * from public.claim_share_reward()');
  await as(0);
  assert.equal(r.success, true, 'TABAN KUSURU: hiç oynamamış hesap doğrudan RPC ile 25 jeton alır');
}
// #5 kısıtlı hesap ödül yollarında
await kisitla(3);
{
  const rs = await claimSolo(3, await tur(3, 10, 6, 40));
  assert(rs.amount > 0, 'TABAN KUSURU: kısıtlı hesap solo ödülü alır');
  await as(3);
  const sh = await one('select * from public.claim_share_reward()');
  assert.equal(sh.success, true, 'TABAN KUSURU: kısıtlı hesap paylaşım ödülü alır');
  await as(0);
  await db.query("insert into tournaments(id, status) values ($1, 'open')", [R(1)]);
  await db.query("insert into tournament_entries(tournament_id, player_id) values ($1, $2)", [R(1), U(3)]);
}
// #7 spend_coins_once uyuşmazlık
{
  await as(1);
  await db.query("select public.spend_coins_once(10, 'shop', 'K1')");
  const r = (await one("select public.spend_coins_once(999, 'baska', 'K1') r")).r;
  await as(0);
  assert.equal(r.success, true, 'TABAN KUSURU: aynı anahtar farklı tutarla "başarı" döner');
}
// #10 record_activity sayacı
const solo7 = async () => Number((await one("select coalesce(sum(n),0) s from usage_mode_counter where mode = 'solo'")).s);
{
  const once = await solo7();
  await as(9);
  for (let i = 0; i < 60; i++) await db.query('select public.record_activity(true)');
  await as(0);
  assert.equal((await solo7()) - once, 60, 'TABAN KUSURU: record_activity(true) sınırsız şişirir');
}
// #6 katkı ödülü tekrarı
const coinsOf = async u => Number((await one('select coins from profiles where id = $1', [u])).coins);
{
  const c0 = await coinsOf(U(5));
  await as(4);
  await db.query('select public.admin_reward_contributor($1, 100, null)', [U(5)]);
  await db.query('select public.admin_reward_contributor($1, 100, null)', [U(5)]);
  await as(0);
  assert.equal((await coinsOf(U(5))) - c0, 200, 'TABAN KUSURU: aynı istek ikinci kez ödenir');
}
// Lig: kısıtlı oyuncu kümeye girer + listede görünür; ack hepsini kapatır
const hafta = (await one("select to_char(public.weekly_league_week_start(), 'YYYY-MM-DD') w")).w;
const ligOku = async u => ok(u, async () => (await one('select public.get_my_league() r')).r);
{
  for (const u of [3, 10, 11, 12]) {
    await db.query('insert into player_score_daily(player_id, day, score) values ($1, public.app_today(), $2)', [U(u), 100 + u]);
  }
  const l10 = await ligOku(10);
  assert(l10.members.some(m => m.player_id === U(10)));
  const l3 = await ligOku(3);
  assert.equal(l3.joined, true, 'TABAN KUSURU: kısıtlı oyuncu lig kümesine girer');
  const l11 = await ligOku(11);
  assert(l11.members.some(m => m.player_id === U(3)), 'TABAN KUSURU: kısıtlı oyuncu küme listesinde görünür');
  // iki okunmamış sonuç
  const c = (await one("insert into weekly_league_cohorts(week_start, tier) values ($1::date - 7, 0) returning id", [hafta])).id;
  const c2 = (await one("insert into weekly_league_cohorts(week_start, tier) values ($1::date - 14, 0) returning id", [hafta])).id;
  await db.query("insert into weekly_league_closed(week_start) values ($1::date - 7), ($1::date - 14) on conflict do nothing", [hafta]);
  await db.query("insert into weekly_league_members(week_start, player_id, cohort_id, tier, outcome, new_tier, final_rank, final_score) values ($1::date - 7, $2, $3, 0, 'promoted', 1, 1, 50), ($1::date - 14, $2, $4, 0, 'stayed', 0, 2, 40)", [hafta, U(12), c, c2]);
  const once = await ligOku(12);
  assert.equal(once.last_result.outcome, 'promoted', 'en yeni okunmamış sonuç gösterilir');
  await as(12); await db.query('select public.ack_my_league_result()'); await as(0);
  const sonra = await ligOku(12);
  assert.equal(sonra.last_result, null, 'TABAN KUSURU: ack gösterilmeyen eski sonucu da kapatır');
  await db.query("update weekly_league_members set result_seen = false where player_id = $1", [U(12)]);
}
// push_delivery_v2_allowed
const allowed = async (to, from, kind, ageMin = 1, data = '{}') =>
  (await one("select public.push_delivery_v2_allowed($1, $2, $3, now() - make_interval(mins => $4), $5::jsonb) a", [to, from, kind, ageMin, data])).a;
{
  assert.equal(await allowed(U(13), U(14), 'friend_request'), true, 'TABAN KUSURU: istek hiç yokken bile arkadaşlık bildirimi geçer');
  assert.equal(await allowed(U(13), null, 'admin_report'), true, 'TABAN KUSURU: yönetici olmayana admin bildirimi geçer');
  await db.query("update profiles set push_duel = false, push_social = false where id = $1", [U(4)]);
  assert.equal(await allowed(U(4), null, 'admin_report'), true, 'TABAN KUSURU: ana anahtar kapalıyken yönetici push\'u geçer');
  await db.query("update profiles set push_duel = true, push_social = true where id = $1", [U(4)]);
  await db.query("insert into admin_notify_prefs(admin_id, kind, enabled) values ($1, 'report', false)", [U(4)]);
  assert.equal(await allowed(U(4), null, 'admin_report'), true, 'TABAN KUSURU: tercih kapatılsa da kuyruktaki iş geçer');
  await db.query("delete from admin_notify_prefs");
}
// admin_enqueue_push: hata asıl kaydı bozmaz (taban davranışı), sessizdir
{
  await db.exec('alter table push_outbox rename to push_outbox_x');
  await db.query('insert into suggested_questions(user_id, prompt) values ($1, $2)', [U(6), 'hata']);
  await db.exec('alter table push_outbox_x rename to push_outbox');
}

// ====================== Göç ======================
await uygula();
console.log('göç uygulandı');
await uygula();
console.log('göç iki kez uygulandı (idempotent)');
assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w1:%'")).c, 11, '11 yedek');

// ====================== SON: düzeltmeler ======================
// #2
{
  const bos = await claimSolo(1, await tur(1, 1, 0, 3));
  assert.equal(bos.amount, 0); assert.equal(bos.not_eligible, true);
  const sifir = await claimSolo(1, await tur(1, 10, 0, 40));
  assert.equal(sifir.amount, 0, 'sıfır doğru: taban ödül yok');
  const hizli = await claimSolo(1, await tur(1, 10, 5, 2));
  assert.equal(hizli.amount, 0, 'anında biten tur ödül vermez');
  const normal = await claimSolo(1, await tur(1, 10, 6, 40));
  assert(normal.amount >= 4 + 6, 'dürüst tur ödülünü alır: ' + JSON.stringify(normal));
  assert.equal(normal.not_eligible, undefined);
  const bes = await claimSolo(1, await tur(1, 5, 1, 30));
  assert(bes.amount > 0, 'ilk oturum (5 soru, 1 doğru) hâlâ ödül alır');
  // Aynı sonuç yeniden istenince saklı yanıt (tek soruluk tur da).
  const id = await tur(1, 1, 0, 3);
  const a = await claimSolo(1, id); const b = await claimSolo(1, id);
  assert.equal(a.amount, 0); assert.equal(b.amount, 0); assert.equal(b.already_claimed, true);
  // Kısıtlı hesap: ödül yok, oturum kaydı da yazılmaz (kısıt kalkınca alabilir).
  const rid = await tur(3, 10, 6, 40);
  const rs = await claimSolo(3, rid);
  assert.equal(rs.amount, 0); assert.equal(rs.account_restricted, true);
  assert.equal((await one('select reward_result from verified_quiz_sessions where client_round_id = $1', [rid])).reward_result, null);
}
// #11 davet
{
  // Yeni hesaplar: 14 yalnız tek soruluk boş tur oynadı, 15 dürüst tur oynadı, davet eden 2 (zaten 1 ödül)
  await claimSolo(14, await tur(14, 1, 0, 3));
  await as(14);
  const r = (await one('select public.redeem_referral_code($1) r', ['T002'])).r;
  await as(0);
  assert.equal(r.success, false); assert.equal(r.error, 'not_active', 'boş tur davet ödülünü artık açmaz');
  await claimSolo(15, await tur(15, 10, 7, 40));
  await as(15);
  const r2 = (await one('select public.redeem_referral_code($1) r', ['T002'])).r;
  await as(0);
  assert.equal(r2.success, true, 'dürüst tur davet ödülünü açar');
  // Kısıtlı çağıran / kısıtlı davet eden
  await claimSolo(16, await tur(16, 10, 7, 40));
  await as(3);
  const rc = (await one('select public.redeem_referral_code($1) r', ['T002'])).r;
  await as(0);
  assert.equal(rc.success, false); assert.equal(rc.error, 'account_restricted');
  await as(16);
  const rr = (await one('select public.redeem_referral_code($1) r', ['T003'])).r; // T003 = kısıtlı kullanıcı 3
  await as(0);
  assert.equal(rr.success, false); assert.equal(rr.error, 'code_not_found', 'kısıtlı davet eden kodu yokmuş gibi');
  assert.equal((await one('select count(*)::int c from referral_redemptions where user_id = $1', [U(16)])).c, 0);
}
// #1 paylaşım
{
  const sh = async u => ok(u, async () => await one('select * from public.claim_share_reward()'));
  const bos = await sh(17);
  assert.equal(bos.success, false); assert.equal(bos.message, 'No verified play today');
  // 1 soruluk boş tur etkinlik sayılmaz
  await tur(17, 1, 0, 3);
  assert.equal((await sh(17)).success, false);
  await tur(17, 10, 4, 30);
  const iyi = await sh(17);
  assert.equal(iyi.success, true); assert.equal(iyi.reward_amount, 25);
  assert.equal((await sh(17)).message, 'Already claimed today');
  // düello sonucu etkinliktir
  await db.query("insert into async_duel_results(duel_id, player_id) values (gen_random_uuid(), $1)", [U(18)]);
  assert.equal((await sh(18)).success, true, 'bitmiş düello etkinlik sayılır');
  // oda ödülü kaydı etkinliktir
  await db.query("insert into coin_transactions(player_id, amount, reason) values ($1, 10, 'quiz_complete:abc')", [U(19)]);
  assert.equal((await sh(19)).success, true, 'oda ödülü kaydı etkinlik sayılır');
  // dünün etkinliği bugünü açmaz
  await db.query("insert into coin_transactions(player_id, amount, reason, created_at) values ($1, 10, 'solo_round', now() - interval '2 days')", [U(20)]);
  assert.equal((await sh(20)).success, false, 'eski gün etkinliği bugünün ödülünü açmaz');
  // kısıtlı
  const k = await sh(3);
  assert.equal(k.success, false); assert.equal(k.message, 'account_restricted');
}
// #7
{
  await as(1);
  await db.query("select public.spend_coins_once(10, 'shop', 'K2')");
  const ayni = (await one("select public.spend_coins_once(10, 'shop', 'K2') r")).r;
  const tutar = (await one("select public.spend_coins_once(999, 'shop', 'K2') r")).r;
  const neden = (await one("select public.spend_coins_once(10, 'baska', 'K2') r")).r;
  await as(0);
  assert.equal(ayni.success, true); assert.equal(ayni.idempotent, true);
  assert.equal(tutar.success, false); assert.equal(tutar.error, 'idempotency_key_mismatch');
  assert.equal(neden.success, false); assert.equal(neden.error, 'idempotency_key_mismatch');
}
// #10
{
  const once = await solo7();
  await as(9);
  for (let i = 0; i < 60; i++) await db.query('select public.record_activity(true)');
  await as(0);
  assert.equal((await solo7()) - once, 30, 'kullanıcı başına günde en çok 30');
  assert.equal((await one('select solo_n from usage_daily_active where user_id = $1 and day = public.app_today()', [U(9)])).solo_n, 30);
  await as(9);
  for (let i = 0; i < 5; i++) await db.query('select public.record_activity(false)');
  await as(0);
  assert.equal((await solo7()) - once, 30, 'solo olmayan çağrı sayacı etkilemez');
}
// #6
{
  const c0 = await coinsOf(U(5));
  await as(4);
  const kimlik = '40000000-0000-0000-0000-000000000001';
  await db.query('select public.admin_reward_contributor($1, 100, null, $2)', [U(5), kimlik]);
  await db.query('select public.admin_reward_contributor($1, 100, null, $2)', [U(5), kimlik]);
  assert.equal((await coinsOf(U(5))) - c0, 100, 'aynı request_id: tek ödeme');
  await assert.rejects(db.query('select public.admin_reward_contributor($1, 250, null, $2)', [U(5), kimlik]), /request_id_conflict/); await kapat();
  await as(4);
  await assert.rejects(db.query('select public.admin_reward_contributor($1, 100, null, null)', [U(5)]), /bad_request_id/); await kapat();
  await as(4);
  await db.query('select public.admin_reward_contributor($1, 100, null, $2)', [U(5), '40000000-0000-0000-0000-000000000002']);
  assert.equal((await coinsOf(U(5))) - c0, 200, 'farklı request_id yeni ödeme');
  // Eski 3 bağımsız değişkenli imza: aynı 10 dk diliminde tekrar = tek ödeme
  const c1 = await coinsOf(U(5));
  await db.query('select public.admin_reward_contributor($1, 123, null)', [U(5)]);
  await db.query('select public.admin_reward_contributor($1, 123, null)', [U(5)]);
  assert.equal((await coinsOf(U(5))) - c1, 123, '3 bağımsız değişkenli eski imza da çift ödemez');
  await as(0);
  assert.equal((await one('select count(*)::int c from admin_contributor_rewards where request_id is null')).c, 2, 'eski taban satırları request_id taşımaz');
  await as(6);
  await assert.rejects(db.query('select public.admin_reward_contributor($1, 100, null, $2)', [U(5), '40000000-0000-0000-0000-000000000009']), /admin_required/); await kapat();
  await as(0);
  // Ödülü 1..5000 dışı reddeder, katkıcı olmayanı reddeder
  await as(4);
  await assert.rejects(db.query('select public.admin_reward_contributor($1, 9999, null, $2)', [U(5), '40000000-0000-0000-0000-000000000003']), /bad_coins/); await kapat();
  await as(4);
  await assert.rejects(db.query('select public.admin_reward_contributor($1, 10, null, $2)', [U(7), '40000000-0000-0000-0000-000000000004']), /not_a_contributor/); await kapat();
  await as(0);
}
// Turnuva
{
  const rejected = async u => {
    try { await db.query("insert into tournament_entries(tournament_id, player_id) values ($1, $2)", [R(2), U(u)]); }
    catch (e) { assert.equal(e.code, '42501'); assert.match(e.message, /account_restricted/); return; }
    assert.fail('kısıtlı hesap turnuvaya yazıldı');
  };
  await db.query("insert into tournaments(id, status) values ($1, 'open')", [R(2)]);
  await rejected(3);
  await db.query("insert into tournament_entries(tournament_id, player_id) values ($1, $2)", [R(2), U(10)]); // kısıtlı olmayan geçer
  // admin_moderate_user: açık turnuvadaki bekleyen kaydı siler, başlamışa dokunmaz
  await db.query("insert into tournaments(id, status) values ($1, 'running')", [R(3)]);
  await db.query("insert into tournament_entries(tournament_id, player_id) values ($1, $2), ($3, $2)", [R(2), U(11), R(3)]);
  await as(4);
  await db.query("select public.admin_moderate_user($1, 'suspend', 3, 'x')", [U(11)]);
  await as(0);
  assert.equal((await one("select count(*)::int c from tournament_entries where player_id = $1 and tournament_id = $2", [U(11), R(2)])).c, 0, 'açık turnuvadaki kayıt silindi');
  assert.equal((await one("select count(*)::int c from tournament_entries where player_id = $1 and tournament_id = $2", [U(11), R(3)])).c, 1, 'başlamış turnuvaya dokunulmadı');
  await as(4); await db.query("select public.admin_moderate_user($1, 'lift', null, null)", [U(11)]); await as(0);
  await db.query("insert into tournament_entries(tournament_id, player_id) values ($1, $2)", [R(2), U(11)]);
  // uyarı kısıtlamaz
  await as(4); await db.query("select public.admin_moderate_user($1, 'warn', null, 'x')", [U(12)]); await as(0);
  await db.query("insert into tournament_entries(tournament_id, player_id) values ($1, $2)", [R(2), U(12)]);
}
// Lig
{
  // Kısıtlı yeni oyuncu: kümeye atanmaz
  await db.query('insert into player_score_daily(player_id, day, score) values ($1, public.app_today(), 77)', [U(14)]);
  await kisitla(14);
  const l14 = await ligOku(14);
  assert.equal(l14.joined, false, 'kısıtlı oyuncu kümeye atanmaz');
  const l10 = await ligOku(10);
  assert(!l10.members.some(m => m.player_id === U(3)), 'kısıtlı üye küme listesinden çıkar');
  assert(!l10.members.some(m => m.player_id === U(14)));
  assert(l10.members.some(m => m.player_id === U(10)), 'kısıtlı olmayanlar görünür');
  // ack yalnız gösterilen en yeni sonucu kapatır
  const once = await ligOku(12);
  assert.equal(once.last_result.outcome, 'promoted');
  await as(12); await db.query('select public.ack_my_league_result()'); await as(0);
  const sonra = await ligOku(12);
  assert.equal(sonra.last_result.outcome, 'stayed', 'eski okunmamış sonuç sırayla gelir');
  await as(12); await db.query('select public.ack_my_league_result()'); await as(0);
  assert.equal((await ligOku(12)).last_result, null);
  // Telafi kapanışı cron'dan sonra: gövdede 10 dk eşiği; şimdi eşiğin içindeysek davranışı da sına.
  const gov = await defOf(IMZA.lg);
  assert(gov.includes("+ interval '10 minutes'"));
  const gecen = (await one("select (now() >= (public.weekly_league_week_start()::timestamp at time zone 'Europe/Istanbul') + interval '10 minutes') g")).g;
  if (gecen) {
    await db.query("delete from weekly_league_closed");
    await db.query("insert into weekly_league_members(week_start, player_id, cohort_id, tier) select $1::date - 7, $2, id, 0 from weekly_league_cohorts where week_start = $1::date - 7 limit 1 on conflict do nothing", [hafta, U(13)]);
    await ligOku(13);
    assert.equal((await one("select count(*)::int c from weekly_league_closed where week_start = $1::date - 7", [hafta])).c, 1, 'eşik sonrası telafi kapanışı çalışır');
  } else console.log('NOT: pazartesi 00:00-00:10 penceresi; telafi davranış testi atlandı');
}
// push_delivery_v2_allowed
{
  // arkadaşlık: istek yok -> gitmez; bekleyen -> gider; reddedilmiş -> gitmez
  assert.equal(await allowed(U(13), U(14), 'friend_request'), false, 'istek yoksa bildirim gitmez');
  await db.query("insert into friend_requests(from_user_id, to_user_id, status) values ($1, $2, 'pending')", [U(14), U(13)]);
  assert.equal(await allowed(U(13), U(14), 'friend_request'), true);
  await db.query("update friend_requests set status = 'rejected'");
  assert.equal(await allowed(U(13), U(14), 'friend_request'), false, 'iptal/ret edilmiş istek bildirimi gitmez');
  await db.query("update friend_requests set status = 'accepted'");
  // kabul bildirimi: kabul eden (from) = to_user_id; alıcı (to) = isteği gönderen
  assert.equal(await allowed(U(14), U(13), 'friend_accept'), true);
  await db.query("delete from friend_requests");
  assert.equal(await allowed(U(14), U(13), 'friend_accept'), false, 'silinen arkadaşlığın kabul bildirimi gitmez');
  // from_user_id yoksa (eski kimliksiz iş) arkadaşlık denetimi atlanır (geri uyum)
  assert.equal(await allowed(U(13), null, 'friend_request'), true);
  // diğer türler etkilenmez
  assert.equal(await allowed(U(13), null, 'async_duel_turn'), true);
  // yönetici push'ları
  assert.equal(await allowed(U(13), null, 'admin_report'), false, 'yönetici olmayana gitmez');
  assert.equal(await allowed(U(4), null, 'admin_report'), true);
  assert.equal(await allowed(U(4), null, 'admin_suggestion'), true);
  await db.query("update profiles set push_duel = false, push_social = false where id = $1", [U(4)]);
  assert.equal(await allowed(U(4), null, 'admin_report'), false, 'ana anahtar kapalı');
  await db.query("update profiles set push_duel = false, push_social = true where id = $1", [U(4)]);
  assert.equal(await allowed(U(4), null, 'admin_report'), true, 'tek kategori açıksa gider');
  await db.query("update profiles set push_duel = true, push_social = true where id = $1", [U(4)]);
  await db.query("insert into admin_notify_prefs(admin_id, kind, enabled) values ($1, 'report', false)", [U(4)]);
  assert.equal(await allowed(U(4), null, 'admin_report'), false, 'kuyruktaki iş tercih kapanınca gitmez');
  assert.equal(await allowed(U(4), null, 'admin_suggestion'), true, 'öteki tür etkilenmez');
  await db.query("delete from admin_notify_prefs");
  // 24 saatten eski iş hâlâ elenir
  assert.equal(await allowed(U(4), null, 'admin_report', 60 * 25), false);
}
// admin_enqueue_push: gövde artık WARNING yazar, asıl kayıt yine bozulmaz
{
  assert((await defOf(IMZA.enq)).includes("raise warning 'admin_enqueue_push: % (%)', sqlerrm, sqlstate;"));
  await db.exec('alter table push_outbox rename to push_outbox_x');
  await db.query('insert into suggested_questions(user_id, prompt) values ($1, $2)', [U(6), 'hata2']);
  await db.exec('alter table push_outbox_x rename to push_outbox');
  assert.equal((await one("select count(*)::int c from suggested_questions where prompt = 'hata2'")).c, 1, 'enqueue hatası asıl kaydı bozmaz');
}

// ======================= Güvenlik / yedek / geri alma =======================
{
  for (const v of Object.values(IMZA)) {
    const p = await one(`select prosecdef, proconfig, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('public', p.oid, 'execute') b from pg_proc p where p.oid = '${v}'::regprocedure`);
    assert(p.proconfig && p.prosecdef && !p.a && !p.b, v);
  }
  for (const s of ['public.admin_reward_contributor(uuid,integer,text,uuid)', 'public.w1_guard_tournament_entry()']) {
    const p = await one(`select prosecdef, proconfig, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('public', p.oid, 'execute') b from pg_proc p where p.oid = '${s}'::regprocedure`);
    assert(p.proconfig && p.prosecdef && !p.a && !p.b, s);
  }
  assert.equal((await one("select has_function_privilege('authenticated', 'public.admin_reward_contributor(uuid,integer,text,uuid)'::regprocedure, 'execute') x")).x, true);
  const ya = await q("select ad, tanim from olcek_tur3_yedek where ad like 'w1:%'");
  assert.equal(ya.length, 11);
  for (const y of ya) assert(/-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$/.test(y.tanim), 'yedek iki md5 taşır: ' + y.ad);
  const yamali = {};
  for (const [k, v] of Object.entries(IMZA)) yamali[k] = await defOf(v);
  const yedekler = await q('select * from olcek_tur3_yedek');
  await db.exec('set role anon');
  await assert.rejects(db.query('select public.claim_share_reward()'), /permission denied/); await kapat();
  await db.exec('reset role');

  // Ya hep ya hiç: tek yedek eksik -> hiçbir şey dönmez.
  await db.exec("delete from olcek_tur3_yedek where ad = 'w1:public.admin_enqueue_push()'");
  await assert.rejects(db.exec(geri), /yedek satırı yok/); await kapat();
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), yamali[k], 'eksik yedekte ' + k + ' dönmedi');
  await db.query("insert into olcek_tur3_yedek select * from unnest($1::text[], $2::text[], $3::timestamptz[]) on conflict do nothing",
    [yedekler.map(y => y.ad), yedekler.map(y => y.tanim), yedekler.map(y => y.alindi)]);
  // Bozuk md5 zinciri.
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:', '-- md5:0') where ad like 'w1:%'");
  await assert.rejects(db.exec(geri), /bozuk/); await kapat();
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:0', '-- md5:') where ad like 'w1:%'");
  // Uygulanmış dalda yedek yoksa ileri göç durur.
  const kopya = await q("select * from olcek_tur3_yedek where ad like 'w1:%'");
  await db.exec("delete from olcek_tur3_yedek where ad like 'w1:%'");
  await assert.rejects(uygula(), /yedek satırı\/md5 zinciri sağlam değil/); await kapat();
  for (const y of kopya) await db.query('insert into olcek_tur3_yedek values ($1,$2,$3)', [y.ad, y.tanim, y.alindi]);
  // Göçten sonra gövde değişmişse geri alma durur.
  await db.exec(yamali.spend.replace('v_prev record;', 'v_prev record; /*x*/'));
  await assert.rejects(db.exec(geri), /canlı gövdesi göçten sonra değişmiş/); await kapat();
  await db.exec(yamali.spend);
  // Sızdıran yedek ACL'i: ileri göç durur.
  await db.exec('create role baska; grant select on olcek_tur3_yedek to baska');
  await assert.rejects(uygula(), /relacl/); await kapat();
  await db.exec('revoke all on olcek_tur3_yedek from baska');
  // İşlev yoksa yeniden yaratma yok.
  await db.exec('drop function public.claim_share_reward()');
  await assert.rejects(db.exec(geri), /yok; geri alma durdu/); await kapat();
  await db.exec(yamali.share);
  await db.exec('revoke all on function public.claim_share_reward() from public, anon; grant execute on function public.claim_share_reward() to authenticated');

  // Geri alma: eski gövdeler birebir; yeni nesneler silinir.
  await db.exec(geri);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), tabanDef[k], 'geri alma birebir: ' + k);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w1:%'")).c, 0);
  assert.equal((await one("select to_regprocedure('public.admin_reward_contributor(uuid,integer,text,uuid)') p")).p, null);
  assert.equal((await one("select to_regprocedure('public.w1_guard_tournament_entry()') p")).p, null);
  assert.equal((await one("select count(*)::int c from pg_trigger where tgname = 'trg_w1_tournament_entries_restricted'")).c, 0);
  // Beklenmeyen canlı gövde: ileri göç durur, hiçbir şey kalmaz.
  await db.exec("create or replace function public.spend_coins_once(p_amount integer, p_reason text, p_idempotency_key text) returns jsonb language sql security definer set search_path to 'public' as $$ select '{}'::jsonb $$");
  await assert.rejects(uygula(), /ne bilinen canlı taban ne de/); await kapat();
  await db.exec(tabanDef.spend);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w1:%'")).c, 0);
  await uygula(); // yeniden ileri
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'w1:%'")).c, 11);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOf(v), yamali[k], 'yeniden ileri aynı gövde: ' + k);
  console.log('yedek/md5 zinciri, ya hep ya hiç, beklenmeyen gövde, geri alma ve yeniden ileri doğru');
}
console.log('TAMAM');
