// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_yonetim_moderasyon_local.mjs /mutlak/yol/pglite/dist/index.js
//
// 2026-11-13_yonetim_moderasyon.sql: sahibin "engelle / askıya al" kararı OYUNDA
// işler. Her kusur ÖNCE eski (canlı taban) gövdede/şemada gösterilir, sonra göç
// uygulanır ve düzeltme kanıtlanır:
//  1 engelli oyuncu odaya katılır  2 düello açar  3 düelloyu kabul eder
//  4 sohbete yazar  5 genel sıralamada görünür  6 günün yarışması panosunda görünür.
// Ayrıca: uyarı kısıtlamaz, süresi dolan askı kısıtlamaz, kaldırma geri açar, odayı
// terk edebilir; yedek/md5 zinciri, ikinci uygulama no-op, beklenmeyen gövde göçü
// DURDURUR, geri alma eski gövdeleri birebir döndürür, yeniden ileri göç çalışır.
// Taban gövdeler canlı zincirden yeniden kurulur (migrasyon dosyalarından); md5
// sabitleri göçteki ile BİREBİR eşit olmalı (canlıda ayrıca doğrulanır).
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
const forward = read('2026-11-13_yonetim_moderasyon.sql');
const rollback = read('geri_al/2026-11-13_yonetim_moderasyon_geri.sql');
const paneli = read('2026-11-12_yonetim_paneli.sql');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const R = n => '30000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const q = async (sql, args = []) => (await db.query(sql, args)).rows;
const one = async (sql, args = []) => (await q(sql, args))[0];
const defOf = async sig => (await one(`select pg_get_functiondef('${sig}'::regprocedure) d`)).d;
const raisesRestricted = async (label, sql, args = []) => {
  try { await db.query(sql, args); }
  catch (e) { assert.equal(e.code, '42501', `${label}: ${e.code} ${e.message}`); assert.match(e.message, /account_restricted/, label); return; }
  assert.fail(`${label}: kısıtlı hesap REDDEDİLMEDİ`);
};
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  create function app_today() returns date language sql stable
    as $$ select (now() at time zone 'Europe/Istanbul')::date $$;
  create table profiles(id uuid primary key, display_name text, coins int not null default 0, xp int not null default 0,
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
    reason text, created_at timestamptz default now());
  create table coin_transactions(id uuid primary key default gen_random_uuid(), player_id uuid, amount int, reason text,
    created_at timestamptz default now());
  create table rooms(id uuid primary key default gen_random_uuid(), created_at timestamptz default now(),
    status text default 'lobby', finished_at timestamptz, ended_reason text);
  create table room_players(room_id uuid not null, player_id uuid not null, score int not null default 0,
    streak int not null default 0, primary key(room_id, player_id));
  create table room_messages(id uuid primary key default gen_random_uuid(), room_id uuid, sender_id uuid, text text);
  create table async_duels(id uuid primary key default gen_random_uuid(), creator_id uuid not null,
    opponent_id uuid, invited_id uuid, status text default 'open', created_at timestamptz default now());
  create table tournaments(id uuid primary key default gen_random_uuid(), opened_at timestamptz default now());
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
`);

// --- Canlı taban gövdeler (migrasyon zincirinden) ------------------------------
const olcek = read('2026-11-04_olcek_sertlestirme.sql');
const tur4 = read('2026-11-05_olcek_tur4.sql');
let ldr = fnText(olcek, 'leaderboard_daily_rows');
// tur4 yaması (tüm zamanlar player_score_total'dan): göçün $e$/$y$ çiftini AYNEN uygula.
{
  const i = tur4.indexOf("'public.leaderboard_daily_rows(integer,uuid[])',");
  const e0 = tur4.indexOf('$e$', i) + 3, e1 = tur4.indexOf('$e$', e0);
  const y0 = tur4.indexOf('$y$', e1) + 3, y1 = tur4.indexOf('$y$', y0);
  const eski = tur4.slice(e0, e1), yeni = tur4.slice(y0, y1);
  assert(ldr.includes(eski) && ldr.split(eski).length === 2, 'tur4 eski parça taban gövdede tam bir kez olmalı');
  ldr = ldr.replace(eski, () => yeni);
}
const gunluk = read('2026-10-24_gunun_yarismasi_sonuc.sql');
let board = fnText(gunluk, 'get_daily_event_board');
board = board.replace('public.get_daily_event_board()', 'public.get_verified_daily_event_board()')
             .replace('public.daily_event_results', 'public.verified_daily_event_results');
await db.exec(`
  create or replace function public.user_is_restricted(p_user uuid) returns boolean language sql stable
    security definer set search_path = public, pg_temp as $f$ select false $f$;`);   // 11-12 gelince gerçeği ezer
await db.exec(ldr);
await db.exec(`revoke all on function public.leaderboard_daily_rows(integer, uuid[]) from public, anon, authenticated;`);
await db.exec(fnText(olcek, 'get_leaderboard') + fnText(olcek, 'get_my_leaderboard_rank') + fnText(olcek, 'get_friends_leaderboard'));
await db.exec(board);
await db.exec(`alter function public.get_verified_daily_event_board() set search_path = public, pg_temp;
  revoke all on function public.get_verified_daily_event_board() from public, anon;
  grant execute on function public.get_verified_daily_event_board() to authenticated;
  revoke all on function public.get_leaderboard(integer, integer) from public, anon;
  grant execute on function public.get_leaderboard(integer, integer) to authenticated;`);
await db.exec(paneli);   // gerçek 11-12 göçü: user_moderation, user_is_restricted, admin_*
const IMZA_LDR = 'public.leaderboard_daily_rows(integer,uuid[])', IMZA_GVB = 'public.get_verified_daily_event_board()';
const tabanLdr = md5(await defOf(IMZA_LDR)), tabanGvb = md5(await defOf(IMZA_GVB));
const eskiLdr = await defOf(IMZA_LDR), eskiGvb = await defOf(IMZA_GVB);
// Göçteki taban sabitleri zincirden yeniden kurulan gövdeyle BİREBİR aynı olmalı.
const sabit = n => { const m = new RegExp("'" + n + "', '([0-9a-f]{32}|__[A-Z_]+__)'").exec(forward); return m && m[1]; };
const gomuluTaban = [...forward.matchAll(/\('(public\.[a-z_]+\([^)]*\))', '([0-9a-f]{32})', '([0-9a-f]{32})'\)/g)];
if (gomuluTaban.length !== 2) { console.log('TABAN_LDR=' + tabanLdr + '\nTABAN_GVB=' + tabanGvb); }
else {
  const by = Object.fromEntries(gomuluTaban.map(m => [m[1], m]));
  assert.equal(by[IMZA_LDR][2], tabanLdr, 'leaderboard_daily_rows taban md5 göçtekiyle farklı');
  assert.equal(by[IMZA_GVB][2], tabanGvb, 'get_verified_daily_event_board taban md5 göçtekiyle farklı');
}

// --- Veri ----------------------------------------------------------------------
const ADMIN = 1, BAD = 2, GOOD = 3, WARNED = 4, SUSP = 5, FRIEND = 6;
for (let i = 1; i <= 6; i++) {
  await q('insert into auth.users values ($1)', [U(i)]);
  await q('insert into profiles(id, display_name) values ($1, $2)', [U(i), 'Oyuncu' + i]);
}
await q('insert into admins(user_id) values ($1)', [U(ADMIN)]);
const room = (await one(`insert into rooms(status) values ('lobby') returning id`)).id;
await q('insert into room_players(room_id, player_id) values ($1, $2)', [room, U(GOOD)]);
const today = (await one('select app_today()::text d')).d;
for (const [u, correct, secs] of [[BAD, 10, 20], [GOOD, 9, 30], [WARNED, 8, 40]])
  await q('insert into verified_daily_event_results(day, user_id, correct_count, seconds) values ($1, $2, $3, $4)', [today, U(u), correct, secs]);
// Tüm zamanlar sıralaması: BAD birinci.
for (const [u, sc] of [[BAD, 9000], [GOOD, 5000], [WARNED, 3000]])
  await q('insert into player_score_total(player_id, score, streak, rooms) values ($1, $2, 3, 2)', [U(u), sc]);
for (const [u, sc] of [[BAD, 700], [GOOD, 500]])
  await q('insert into player_score_daily(player_id, day, score, streak, rooms) values ($1, app_today(), $2, 3, 2)', [U(u), sc]);

const board0 = async who => { await as(who); return (await one('select public.get_verified_daily_event_board() b')).b; };
const lb = async (days = -1) => { await as(GOOD); return (await q('select player_id from public.get_leaderboard($1, 10)', [days])).map(r => r.player_id); };

// --- Engelle: sahibin işlemi (gerçek admin_moderate_user) -------------------------
await as(ADMIN);
await q('select public.admin_moderate_user($1, $2, null, $3)', [U(BAD), 'block', 'test']);
await q('select public.admin_moderate_user($1, $2, 3, $3)', [U(SUSP), 'suspend', 'test']);
await q('select public.admin_moderate_user($1, $2, null, $3)', [U(WARNED), 'warn', 'test']);
assert.equal((await one('select public.user_is_restricted($1) v', [U(BAD)])).v, true);
assert.equal((await one('select public.user_is_restricted($1) v', [U(SUSP)])).v, true);
assert.equal((await one('select public.user_is_restricted($1) v', [U(WARNED)])).v, false, 'uyarı kısıtlamaz');
assert.equal((await one('select public.user_is_restricted($1) v', [U(GOOD)])).v, false);
assert.equal((await one('select public.user_is_restricted(null) v')).v, false);

// --- KUSUR ÖNCE: eski şemada/gövdede engelli oyuncu her yerde -----------------------
const joinSql = 'insert into room_players(room_id, player_id) values ($1, $2)';
await q(joinSql, [room, U(BAD)]);                                           // 1 katılır
await q('delete from room_players where player_id = $1', [U(BAD)]);
const d0 = (await one('insert into async_duels(creator_id) values ($1) returning id', [U(BAD)])).id;   // 2 açar
const d1 = (await one('insert into async_duels(creator_id) values ($1) returning id', [U(GOOD)])).id;
await q('update async_duels set opponent_id = $1, status = $2 where id = $3', [U(BAD), 'matched', d1]);   // 3 kabul
await q('delete from async_duels');
await as(BAD);
await q('insert into room_messages(room_id, sender_id, text) values ($1, $2, $3)', [room, U(BAD), 'merhaba']);   // 4 yazar
await q('delete from room_messages');
assert.equal((await lb())[0], U(BAD), 'öncesi: engelli oyuncu genel sıralamada BİRİNCİ');                       // 5
assert.equal((await board0(GOOD)).top[0].correct, 10, 'öncesi: engelli oyuncu günün yarışmasında BİRİNCİ');    // 6
assert.equal((await board0(GOOD)).participants, 3);

// --- Göçü uygula ----------------------------------------------------------------
await db.exec(forward).catch(e => { console.log("FWDERR", e.where); throw e; });

// 1-4 kısıtlı hesap reddedilir (kaynağı ne olursa olsun: RPC'ler bu tablolara yazar).
await as(BAD);
await raisesRestricted('oda katılımı', joinSql, [room, U(BAD)]);
await raisesRestricted('askıdaki oda katılımı', joinSql, [room, U(SUSP)]);
await raisesRestricted('düello açma', 'insert into async_duels(creator_id) values ($1)', [U(BAD)]);
await raisesRestricted('kısıtlıyı davet', 'insert into async_duels(creator_id, invited_id) values ($1, $2)', [U(GOOD), U(BAD)]);
const d2 = (await one('insert into async_duels(creator_id) values ($1) returning id', [U(GOOD)])).id;
await raisesRestricted('düello kabulü', 'update async_duels set opponent_id = $1, status = $2 where id = $3', [U(BAD), 'matched', d2]);
await raisesRestricted('sohbet', 'insert into room_messages(room_id, sender_id, text) values ($1, $2, $3)', [room, U(BAD), 'merhaba']);
await as(SUSP);
await raisesRestricted('askıdaki sohbet', 'insert into room_messages(room_id, sender_id, text) values ($1, $2, $3)', [room, U(SUSP), 'x']);
// Başkası etkilenmez; yan etki yok.
await q('update async_duels set opponent_id = $1, status = $2 where id = $3', [U(FRIEND), 'matched', d2]);
await q('update async_duels set status = $1 where id = $2', ['completed', d2]);               // opponent değişmeyen güncelleme serbest
await as(GOOD);
await q('insert into room_messages(room_id, sender_id, text) values ($1, $2, $3)', [room, U(GOOD), 'selam']);
await q('insert into async_duels(creator_id, invited_id) values ($1, $2)', [U(GOOD), U(FRIEND)]);
await q(joinSql, [room, U(FRIEND)]);
// Uyarılan oyuncu kısıtlanmaz.
await q(joinSql, [room, U(WARNED)]);
await as(WARNED);
await q('insert into room_messages(room_id, sender_id, text) values ($1, $2, $3)', [room, U(WARNED), 'ben uyarıldım']);
// Zaten odadaki kısıtlı oyuncu odayı TERK edebilir (silme engellenmez).
await db.exec('alter table room_players disable trigger trg_moderation_room_players');
await q(joinSql, [room, U(BAD)]);
await db.exec('alter table room_players enable trigger trg_moderation_room_players');
await q('delete from room_players where room_id = $1 and player_id = $2', [room, U(BAD)]);
assert.equal((await q('select 1 from room_players where player_id = $1', [U(BAD)])).length, 0);

// 5-6 sıralamalar: kısıtlı hesap düşer, sıralar kayar; engeli kaldırınca döner.
assert.deepEqual(await lb(), [U(GOOD), U(WARNED)], 'genel sıralama (tüm zamanlar)');
assert.deepEqual(await lb(7), [U(GOOD)], 'haftalık sıralama (günlük tablodan)');
const b1 = await board0(GOOD);
assert.equal(b1.participants, 2); assert.equal(b1.top[0].correct, 9); assert.equal(b1.top.length, 2);
await as(GOOD);
assert.equal((await q('select * from public.get_my_leaderboard_rank(-1)'))[0].rank, 1);
assert.equal((await q('select * from public.get_friends_leaderboard(-1)')).find(r => r.is_self).total_score, 5000);
await as(ADMIN);
await q('select public.admin_moderate_user($1, $2, null, null)', [U(BAD), 'lift']);
assert.equal((await lb())[0], U(BAD), 'engel kalkınca sıralamaya geri döner');
await as(BAD);
await q(joinSql, [room, U(BAD)]);
await as(ADMIN);
await q('select public.admin_moderate_user($1, $2, null, null)', [U(BAD), 'block']);
// Süresi dolan askı kısıtlamaz.
await q(`update user_moderation set until = now() - interval '1 minute' where user_id = $1`, [U(SUSP)]);
assert.equal((await one('select public.user_is_restricted($1) v', [U(SUSP)])).v, false);
await as(SUSP);
await q('insert into room_messages(room_id, sender_id, text) values ($1, $2, $3)', [room, U(SUSP), 'askı bitti']);
await q(`update user_moderation set until = now() + interval '1 hour' where user_id = $1`, [U(SUSP)]);

// --- Yapı / güvenlik --------------------------------------------------------------
const nihaiLdr = md5(await defOf(IMZA_LDR)), nihaiGvb = md5(await defOf(IMZA_GVB));
assert.notEqual(nihaiLdr, tabanLdr); assert.notEqual(nihaiGvb, tabanGvb);
if (gomuluTaban.length === 2) {
  const by = Object.fromEntries(gomuluTaban.map(m => [m[1], m]));
  assert.equal(by[IMZA_LDR][3], nihaiLdr, 'leaderboard_daily_rows nihai md5');
  assert.equal(by[IMZA_GVB][3], nihaiGvb, 'get_verified_daily_event_board nihai md5');
} else console.log('NIHAI_LDR=' + nihaiLdr + '\nNIHAI_GVB=' + nihaiGvb);
for (const sig of [IMZA_LDR, IMZA_GVB]) {
  const y = (await one('select tanim from olcek_tur3_yedek where ad = $1', ['yonetim:' + sig])).tanim;
  assert(y.includes('-- md5:' + (sig === IMZA_LDR ? tabanLdr : tabanGvb)), 'yedek md5');
  assert(y.endsWith('-- yama-md5:' + (sig === IMZA_LDR ? nihaiLdr : nihaiGvb)), 'yama md5');
}
assert.equal((await one(`select has_table_privilege('authenticated', 'olcek_tur3_yedek', 'select,insert,update,delete') v`)).v, false);
for (const f of ['moderation_guard_room_player()', 'moderation_guard_async_duel()', 'moderation_guard_room_message()']) {
  const r = await one(`select p.prosecdef, p.proconfig,
    has_function_privilege('authenticated', p.oid, 'execute') a, has_function_privilege('anon', p.oid, 'execute') b
    from pg_proc p where p.oid = 'public.${f}'::regprocedure`);
  assert(r.prosecdef && r.proconfig && !r.a && !r.b, f + ' sözleşmesi');
}
// Erişim hakları DEĞİŞMEDİ: leaderboard_daily_rows kimseye, panoya yalnız authenticated.
assert.equal((await one(`select has_function_privilege('authenticated', '${IMZA_LDR}'::regprocedure, 'execute') v`)).v, false);
assert.equal((await one(`select has_function_privilege('anon', '${IMZA_GVB}'::regprocedure, 'execute') v`)).v, false);
assert.equal((await one(`select has_function_privilege('authenticated', '${IMZA_GVB}'::regprocedure, 'execute') v`)).v, true);

// --- İkinci uygulama: no-op (yedek ve gövde değişmez) --------------------------------
const yedekOnce = JSON.stringify(await q('select ad, tanim from olcek_tur3_yedek order by ad'));
await db.exec(forward).catch(e => { console.log("FWDERR", e.where); throw e; });
assert.equal(JSON.stringify(await q('select ad, tanim from olcek_tur3_yedek order by ad')), yedekOnce, 'ikinci uygulama yedeği değiştirdi');
assert.equal(md5(await defOf(IMZA_LDR)), nihaiLdr);

// --- Beklenmeyen canlı gövde: ileri göç VE geri alma DURUR, hiçbir şey değişmez ---------------
const nihaiGvbDef = await defOf(IMZA_GVB);
await db.exec(`create or replace function public.get_verified_daily_event_board() returns jsonb language sql stable
  security definer set search_path = public, pg_temp as $f$ select '{}'::jsonb $f$;`);
const durur = async (label, sql, re) => {
  await assert.rejects(db.exec(sql), re, label);
  await db.exec('rollback').catch(() => {});
};
await durur('geri alma değişmiş gövdede', rollback, /canlı gövdesi göçün yazdığı gövde değil/);
await durur('ileri göç değişmiş gövdede', forward, /ne bilinen canlı taban ne de/);
assert.equal((await one('select count(*)::int n from olcek_tur3_yedek')).n, 2, 'durma yedeği bozdu');
await db.exec(nihaiGvbDef);
assert.equal(md5(await defOf(IMZA_GVB)), nihaiGvb);
// Yedek satırı bozuksa geri alma DURUR (güvenli yol yok).
await q(`update olcek_tur3_yedek set tanim = replace(tanim, '-- yama-md5:', '-- yama-md5:0') where ad = $1`, ['yonetim:' + IMZA_LDR]);
await durur('bozuk yedek', rollback, /yedeği bozuk|canlı gövdesi/);
assert.equal((await one('select count(*)::int n from pg_trigger where tgname like $1', ['trg_moderation_%'])).n, 3, 'durma yarım geri alma bıraktı');
await q(`update olcek_tur3_yedek set tanim = replace(tanim, '-- yama-md5:0', '-- yama-md5:') where ad = $1`, ['yonetim:' + IMZA_LDR]);

// --- Geri alma ve yeniden ileri ----------------------------------------------------------
await db.exec(rollback);
assert.equal(md5(await defOf(IMZA_LDR)), tabanLdr, 'geri alma eski gövdeyi birebir döndürmedi');
assert.equal(md5(await defOf(IMZA_GVB)), tabanGvb, 'geri alma eski gövdeyi birebir döndürmedi');
assert.equal((await one(`select count(*)::int n from pg_trigger where tgname like 'trg_moderation_%'`)).n, 0);
assert.equal((await one(`select count(*)::int n from pg_proc where proname like 'moderation\\_guard\\_%'`)).n, 0);
assert.equal((await one(`select count(*)::int n from olcek_tur3_yedek where ad like 'yonetim:%'`)).n, 0);
assert.equal((await one(`select has_function_privilege('authenticated', '${IMZA_GVB}'::regprocedure, 'execute') v`)).v, true, 'geri alma ACL bozdu');
await q('delete from room_players where player_id = $1', [U(BAD)]);
await as(BAD);
await q(joinSql, [room, U(BAD)]);                                    // geri alınca engel yine işlemez (kusur geri geldi)
await q('delete from room_players where player_id = $1', [U(BAD)]);
await db.exec(forward).catch(e => { console.log("FWDERR", e.where); throw e; });
await raisesRestricted('yeniden ileri: oda katılımı', joinSql, [room, U(BAD)]);
assert.equal(md5(await defOf(IMZA_LDR)), nihaiLdr);

console.log('OK: yönetim moderasyon yerel testi geçti');
await db.close();
