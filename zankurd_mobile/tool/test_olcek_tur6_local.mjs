// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_olcek_tur6_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-05_olcek_tur6.sql için: (A) ücretli oda kurulduktan sonra aynı çağrının
// tekrarı bakiye 0 iken mevcut odayı döner, yeni oda için bakiye hâlâ aranır ve
// reddedilen deneme hız sınırına girmez; (B) kalıcı imleç eski/sığmayan sapmayı
// döngü sonunda onarır, elle tam geri doldurma dilim dilim biter, kalıcı hata
// imleci takmaz; (C) toplam mutabakat dilimi oyuncuyu tekilleştirip sonra LIMIT
// uygular; (D) bracket okuması süre dolumu yürütmez/kilitlemez, cron işi yalnız
// çalışan turnuvaları ilerletir; (E) yamalar idempotent, beklenmeyen gövde göçü
// durdurur, geri alma eski gövdeleri birebir döndürür (ya hep ya hiç).
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
const olcek = read('2026-11-04_olcek_sertlestirme.sql');
const tur3 = read('2026-11-05_olcek_tur3.sql');
const tur4 = read('2026-11-05_olcek_tur4.sql');
const lig = read('2026-11-05_haftalik_lig.sql');
const roomLimits = read('2026-10-31_room_limits.sql');
const turnuvaTaban = read('2026-07-26_real_player_tournament.sql');
const turnuvaAuth = read('2026-07-31_tournament_score_authority.sql');
const turnuvaPuan = read('2026-10-27_turnuva_sunucu_puani.sql');
const turnuvaGonderim = read('2026-10-30_turnuva_gonderim.sql');
let tur6 = read('2026-11-05_olcek_tur6.sql');
const geri = read('geri_al/2026-11-05_olcek_tur6_geri.sql');
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};
const noRls = t => t.replace(/revoke all[^;]*;/gi, '').replace(/grant execute[^;]*;/gi, '')
  .replace(/alter table [^;]*enable row level security;/gi, '');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const R = n => '20000000-0000-0000-0000-' + String(n).padStart(12, '0');
const T = n => '40000000-0000-0000-0000-' + String(n).padStart(12, '0');
const TID = n => '50000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const defOnce = async n => (await db.query(`select pg_get_functiondef('public.${n}'::regprocedure) d`)).rows[0].d;
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
const kapat = async () => { try { await db.exec('rollback'); } catch (e) { /* açık işlem yok */ } };

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  create schema cron;
  create table cron.job(jobid serial primary key, jobname text unique, schedule text, command text);
  create function cron.schedule(n text, s text, c text) returns bigint language sql as
    $$ insert into cron.job(jobname, schedule, command) values (n, s, c)
       on conflict (jobname) do update set schedule = excluded.schedule, command = excluded.command
       returning jobid::bigint $$;
  create function cron.unschedule(n text) returns boolean language sql as
    $$ with d as (delete from cron.job where jobname = n returning 1) select exists(select 1 from d) $$;
  create table profiles(id uuid primary key, display_name text, avatar_icon text,
    avatar_color text, avatar_url text, avatar_frame text, showcase_title text, xp bigint default 0);
  create table blocked_users(blocker_id uuid, blocked_id uuid);
  create table friends(user_id uuid, friend_id uuid);
  create table categories(id uuid primary key default gen_random_uuid(), name text, is_active boolean default true);
  create table rooms(id uuid primary key default gen_random_uuid(), code text unique, host_id uuid,
    category_id uuid, category_ids uuid[], question_count int, seconds_per_question int,
    entry_fee int default 0, is_custom boolean, max_players int,
    status text, ended_reason text, finished_at timestamptz, created_at timestamptz default now());
  create table room_players(room_id uuid, player_id uuid, is_ready boolean, left_at timestamptz,
    joined_at timestamptz default now(), score int, streak int);
  create table matchmaking_queue(player_id uuid primary key, category_name text not null,
    room_id uuid, joined_at timestamptz default now(), last_seen_at timestamptz);
  create table coin_transactions(player_id uuid, amount int, reason text);
  create function public.room_category_label(ids uuid[], n text) returns text language sql as $$ select n $$;
  create table olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
`);
for (let i = 1; i <= 30; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
  await db.query('insert into profiles(id, display_name) values ($1,$2)', [U(i), 'P' + i]);
}
await db.exec("insert into categories(name) values ('Ziman')");

// --- Canlı taban: günlük/toplam sıralama zinciri (11-04 + tur3 + tur4) ---------
const bas = olcek.indexOf('create table if not exists public.player_score_daily');
const son = olcek.indexOf('-- Günlük satırları (pencereye göre)');
await db.exec(noRls(olcek.slice(bas, son)).replace(/create temp table olcek_baslangic[\s\S]*?\n\n/, 'create temp table olcek_baslangic as select clock_timestamp() as t;\n\n'));
for (const n of ['leaderboard_daily_rows', 'get_leaderboard', 'get_friends_leaderboard']) await db.exec(fnText(olcek, n));
await db.exec(fnText(tur3, 'get_my_leaderboard_rank'));
await db.exec(noRls(tur3.slice(tur3.indexOf('create table if not exists public.score_reconcile_log'), tur3.indexOf('-- Son p_days'))));
await db.exec(fnText(tur3, 'reconcile_player_score_daily'));
await db.exec(noRls(lig.slice(lig.indexOf('create table if not exists public.weekly_league_cohorts'), lig.indexOf('-- 4. İstemci RPC')).replace(/-- -+\n$/, '')));
await db.exec(tur4.replace(/alter table [^;]*enable row level security;/gi, ''));
// Hız sınırı yardımcısı (11-04).
await db.exec(noRls(olcek.slice(olcek.indexOf('create table if not exists public.rate_limit_events'),
  olcek.indexOf('-- 2 + 3b. Oda üyeliği kilidi'))));
// create_online_room_impl: room_limits gövdesi + 11-04 yamaları.
await db.exec(fnText(roomLimits, 'create_online_room_impl'));
{
  const yamalar = [...olcek.matchAll(/select pg_temp\.olcek_yama\(\s*'public\.create_online_room_impl\(text\[\],integer,integer,integer,integer,boolean\)'[\s\S]*?\);\n/g)].map(m => m[0]);
  assert.equal(yamalar.length, 2, 'olcek oda yamalari');
  const olcekFn = olcek.slice(olcek.indexOf('create or replace function pg_temp.olcek_yama'), olcek.indexOf('$yama$;') + 7);
  await db.exec('begin;' + olcekFn + yamalar.join('\n') + 'commit;');
}
await db.exec(`revoke all on function public.create_online_room_impl(text[], integer, integer, integer, integer, boolean) from public, anon, authenticated;
  grant execute on function public.create_online_room_impl(text[], integer, integer, integer, integer, boolean) to service_role;
  revoke all on function public.reconcile_player_score_total(integer, integer) from public, anon, authenticated;`);
// Turnuva tabanı: tablolar + 07-26 işlevleri + 07-31 + 10-27 + 10-30 yaması.
await db.exec(`
  create table tournaments(id uuid primary key default gen_random_uuid(), size int not null default 4,
    min_size int not null default 2, fill_hours int not null default 24, status text not null default 'open',
    round_hours int not null default 24, opened_at timestamptz not null default now(), started_at timestamptz,
    finished_at timestamptz, champion_id uuid, scores_server_validated boolean default true);
  create table tournament_entries(tournament_id uuid not null, player_id uuid not null, display_name text not null,
    joined_at timestamptz not null default now(), primary key (tournament_id, player_id));
  create table tournament_matches(id uuid primary key default gen_random_uuid(), tournament_id uuid not null,
    round int not null, slot int not null, player_one uuid, player_two uuid, score_one int, score_two int,
    submitted_one timestamptz, submitted_two timestamptz, winner_id uuid, status text not null default 'pending',
    deadline timestamptz, unique (tournament_id, round, slot));
`);
await db.exec(fnText(turnuvaTaban, 'start_tournament', '$$'));
await db.exec(fnText(turnuvaTaban, 'start_due_tournaments', '$$'));
await db.exec(fnText(turnuvaAuth, 'resolve_expired_tournament_matches', '$$'));
await db.exec(fnText(turnuvaPuan, 'advance_tournament'));
await db.exec(fnText(turnuvaPuan, 'get_tournament_bracket'));
await db.exec(turnuvaGonderim);
await db.exec(`revoke all on function public.resolve_expired_tournament_matches() from public, anon, authenticated;
  grant execute on function public.resolve_expired_tournament_matches() to service_role;`);

const IMZA = {
  oda: 'create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
  toplam: 'reconcile_player_score_total(integer,integer)',
  bracket: 'get_tournament_bracket()',
  coz: 'resolve_expired_tournament_matches()',
};
const tabanDef = {};
for (const [k, v] of Object.entries(IMZA)) tabanDef[k] = await defOnce(v);
const tabanMd5 = Object.fromEntries(Object.entries(tabanDef).map(([k, v]) => [k, md5(v)]));
if (process.env.TUR6_PRINT_MD5) { console.log(JSON.stringify(tabanMd5)); process.exit(0); }
for (const [k, h] of Object.entries({oda: 'TABAN_ODA', toplam: 'TABAN_TOPLAM', bracket: 'TABAN_BRACKET', coz: 'TABAN_COZ'})) {
  if (process.env.TUR6_PRINT_FINAL) tur6 = tur6.replace(h, tabanMd5[k]);
}
if (process.env.TUR6_PRINT_FINAL) {
  // Nihai md5'leri yazdır: son kontrolü kapatıp göçü çalıştır.
  tur6 = tur6.replace('if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> r.nihai then', 'if false then');
  await db.exec(tur6);
  const out = {};
  for (const [k, v] of Object.entries(IMZA)) out[k] = md5(await defOnce(v));
  console.log(JSON.stringify(out));
  process.exit(0);
}
for (const [k, h] of Object.entries(tabanMd5)) assert(tur6.includes(h), 'göçteki taban md5 = repo zincirinden türeyen gövde: ' + k);

// ======================= Veri ve ÖN (göç öncesi) kanıtlar =======================
let rid = 0;
const finishRoom = async (daysAgo, pls, bos = false) => {
  const id = R(++rid);
  await db.query("insert into rooms(id,status,ended_reason,finished_at) values ($1,'active',null,null)", [id]);
  for (const [p, sc, st] of pls) await db.query('insert into room_players(room_id, player_id, score, streak) values ($1,$2,$3,$4)', [id, U(p), sc, st]);
  if (bos) await db.query("update rooms set status='finished' where id=$1", [id]);
  else await db.query("update rooms set status='finished', finished_at = now() - ($2::int * interval '1 day') - interval '1 hour' where id=$1", [id, daysAgo]);
  return id;
};
// C verisi: yalnız U(11..14); p11'in 6 günü, ötekilerin birer günü (hepsi >= 10 gün önce).
for (let d = 0; d < 6; d++) await finishRoom(10 + d, [[11, 10 + d, 1]]);
await finishRoom(12, [[12, 20, 2]]);
await finishRoom(13, [[13, 30, 3]]);
await finishRoom(14, [[14, 40, 4]]);
assert.equal((await one('select count(*)::int c from player_score_daily')).c, 9);
const totalSayi = async () => (await one('select count(*)::int c from player_score_total')).c;
const cursorSifirla = () => db.exec('update score_total_reconcile_cursor set last_player = null');
{
  await db.exec('delete from player_score_total');
  await cursorSifirla();
  for (let i = 0; i < 6; i++) await db.query('select public.reconcile_player_score_total(1, 2)');
  assert.equal(await totalSayi(), 1, 'TABAN HATASI: LIMIT oyuncuyu tekilleştirmeden önce uygulanır, p12-p14 hiç gezilmez');
}
// A: ücretli oda tekrar denemesi bakiye 0 iken reddedilir (taban hatası).
const odaKur = (ucret = 50) => db.query("select public.create_online_room_impl(array['Ziman'], 20, 10, $1, 2, false) r", [ucret]);
await db.query("insert into coin_transactions values ($1, 50, 'seed')", [U(1)]);
await as(1);
const oda1 = (await odaKur()).rows[0].r;
assert.equal((await one('select coalesce(sum(amount),0)::int s from coin_transactions where player_id=$1', [U(1)])).s, 0);
await assert.rejects(odaKur(), /Insufficient coins/, 'TABAN HATASI: idempotent tekrar bakiye 0 iken reddedilir');
// D: bracket okuması taban davranışı: süresi dolmuş maçı kapatır ve turnuvayı bitirir (yan etki).
const turnuva = async (id, durum, kayitlar, maclar, ek = {}) => {
  await db.query(`insert into tournaments(id, status, opened_at, started_at, finished_at, champion_id) values ($1,$2,$3,$4,$5,$6)`,
    [TID(id), durum, ek.opened ?? new Date(), ek.started ?? null, ek.finished ?? null, ek.champion ?? null]);
  for (const p of kayitlar) await db.query('insert into tournament_entries values ($1,$2,$3)', [TID(id), T(p), 'T' + p]);
  for (const m of maclar) {
    await db.query(`insert into tournament_matches(tournament_id, round, slot, player_one, player_two, score_one, score_two, submitted_one, submitted_two, winner_id, status, deadline)
      values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now() + ($12::int * interval '1 hour'))`,
      [TID(id), m.r ?? 1, m.s, T(m.a), m.b ? T(m.b) : null, m.sa ?? null, m.sb ?? null,
       m.suba ? new Date() : null, m.subb ? new Date() : null, m.w ? T(m.w) : null, m.st ?? 'pending', m.dl]);
  }
};
const bracketAs = async n => { await db.exec(`select set_config('test.uid', '${T(n)}', false)`); return (await one('select public.get_tournament_bracket() r')).r; };
// T3: geçmişte bitmiş turnuva; T2: sürüyor, süresi dolmuş TAMAMLANMIŞ maç + gelecekte bekleyen maç.
await turnuva(3, 'finished', [21, 22], [{s: 0, a: 21, b: 22, sa: 5, sb: 3, suba: 1, subb: 1, w: 21, st: 'completed', dl: -72}],
  {finished: new Date('2026-01-01T00:00:00Z'), champion: T(21)});
await turnuva(2, 'running', [5, 6, 7, 8], [
  {s: 0, a: 5, b: 6, sa: 9, sb: 4, suba: 1, subb: 1, w: 5, st: 'completed', dl: -2},
  {s: 1, a: 7, b: 8, dl: 20}], {started: new Date()});
const brSnapOnce = JSON.stringify(await bracketAs(5));
await turnuva(5, 'running', [3, 4], [{s: 0, a: 3, b: 4, dl: -3}], {started: new Date()});
await bracketAs(3);
assert.equal((await one('select status from tournaments where id=$1', [TID(5)])).status, 'finished', 'TABAN: bracket okuması süresi dolan maçı kapatıp turnuvayı bitirir (yan etki)');
await as(0);

// ============================ GÖÇ ============================
const uygula = () => db.exec(tur6);
await uygula();
await uygula(); // idempotent
assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur6:%'")).c, 4, '4 yedek');
console.log('göç iki kez uygulandı (idempotent)');

// (A) ücretli oda tekrarı
{
  await as(1);
  const r2 = (await odaKur()).rows[0].r;
  assert.deepEqual(r2, oda1, 'tekrar çağrı mevcut odayı döner (bakiye 0)');
  assert.equal((await one('select coalesce(sum(amount),0)::int s from coin_transactions where player_id=$1', [U(1)])).s, 0, 'para düşmedi');
  assert.equal((await one('select count(*)::int c from rooms where host_id=$1', [U(1)])).c, 1, 'ikinci oda yok');
  await as(2);
  await assert.rejects(odaKur(), /Insufficient coins/, 'odası olmayan, parası yetmeyen reddedilir');
  assert.equal((await one('select count(*)::int c from rate_limit_events where user_id=$1', [U(2)])).c, 0, 'reddedilen deneme hız sınırına girmedi');
  await db.query("insert into coin_transactions values ($1, 100, 'seed')", [U(3)]);
  await as(3);
  const r3 = (await odaKur()).rows[0].r;
  assert.equal((await one('select coalesce(sum(amount),0)::int s from coin_transactions where player_id=$1', [U(3)])).s, 50, 'yeni oda ücreti düştü');
  assert(r3.room_id && r3.entry_fee === 50);
  await as(4);
  assert((await odaKur(0)).rows[0].r.room_id, 'ücretsiz oda kurulur');
  const d = await defOnce(IMZA.oda);
  const kilit = d.indexOf("'room-membership:'"), profil = d.indexOf('from public.profiles where id = v_uid for update');
  const mevcut = d.indexOf("-- Aktif oda varsa snapshot'ı dön"), bakiye = d.indexOf('Insufficient coins for room entry fee');
  const hiz = d.indexOf("rate_limit_hit('room_create'");
  assert(kilit > 0 && kilit < profil && profil < mevcut && mevcut < bakiye && bakiye < hiz, 'sıra: kilit < profil < mevcut oda < bakiye < hız sınırı');
  assert.equal((d.match(/Insufficient coins/g) || []).length, 1);
  await as(0);
  console.log('A: ücretli oda tekrarı mevcut odayı döner; yeni oda için bakiye aranır; ret hız sınırına girmez');
}

// (C) dönen dilim oyuncuyu tekilleştirir
{
  await db.exec('delete from player_score_total');
  await cursorSifirla();
  for (let i = 0; i < 6; i++) await db.query('select public.reconcile_player_score_total(1, 2)');
  assert.equal(await totalSayi(), 4, 'dönen imleç p11-p14 dört oyuncuya da ulaştı');
  const f = (await one(`select count(*)::int c from (
    select player_id, sum(score)::bigint, max(streak)::bigint, sum(rooms)::bigint from player_score_daily group by 1
    except select player_id, score, streak, rooms from player_score_total) x`)).c;
  assert.equal(f, 0);
  assert((await defOnce(IMZA.toplam)).includes('select distinct d.player_id from public.player_score_daily d'));
  console.log('C: dilim oyuncu başına tekilleştirildi, tüm oyunculara ulaşıldı');
}

// (B) kalıcı imleç + elle tam geri doldurma
const sapma = async () => (await one(`select count(*)::int c from (
  (select rp.player_id, public.score_day_of(r.finished_at) d, coalesce(sum(rp.score),0)::bigint, coalesce(max(rp.streak),0)::bigint, count(distinct rp.room_id)::bigint
     from rooms r join room_players rp on rp.room_id = r.id
    where r.status='finished' and coalesce(r.ended_reason,'completed')='completed' group by 1,2
   except select player_id, day, score, streak, rooms from player_score_daily)
  union all
  (select player_id, day, score, streak, rooms from player_score_daily
   except select rp.player_id, public.score_day_of(r.finished_at), coalesce(sum(rp.score),0)::bigint, coalesce(max(rp.streak),0)::bigint, count(distinct rp.room_id)::bigint
     from rooms r join room_players rp on rp.room_id = r.id
    where r.status='finished' and coalesce(r.ended_reason,'completed')='completed' group by 1,2)) x`)).c;
{
  await finishRoom(0, [[13, 77, 7]], true); // finished_at boş -> '-infinity' kovası
  await finishRoom(1, [[12, 15, 2]]);
  await finishRoom(0, [[12, 5, 1]]); // bugün: gecelik pencerede
  assert.equal(await sapma(), 0, 'başlangıç: sapma yok');
  const eski = (await db.query('select day from player_score_daily where player_id=$1 order by day', [U(11)])).rows.map(r => r.day);
  const kur = async () => {
    await db.query('update player_score_daily set score = score + 1 where player_id=$1 and day=$2', [U(11), eski[0]]);
    await db.query('delete from player_score_daily where player_id=$1 and day=$2', [U(11), eski[2]]);
    await db.query("insert into player_score_daily values ($1, '2020-01-02', 5, 1, 1)", [U(12)]);
    await db.query("update player_score_daily set score = score + 3 where player_id=$1 and day='-infinity'", [U(13)]);
    await db.query("delete from player_score_daily where player_id=$1", [U(14)]);
  };
  await kur();
  const s0 = await sapma();
  assert(s0 >= 5, 'sapma kuruldu: ' + s0);
  // Gecelik (son 2 gün) mutabakatı eski sapmayı GÖRMEZ (taban kusuru).
  await db.query('select public.reconcile_player_score_daily(2)');
  assert.equal(await sapma(), s0, 'son 2 gün penceresi eski sapmayı onarmaz');
  // Kalıcı imleç: küçük dilimlerle çevrim sonunda hepsi onarılır, imleç takılmaz.
  let tur = 0, onceki = '', takildi = 0, sonuc;
  for (; tur < 80; tur++) {
    sonuc = (await one('select public.reconcile_player_score_daily_sweep(3, 2) n')).n;
    assert(sonuc >= 0, 'sweep hata vermedi');
    const c = await one('select last_day::text d, last_player::text p, cycles::int cy from score_reconcile_daily_cursor');
    const imza = c.d + '|' + c.p + '|' + c.cy;
    takildi = imza === onceki ? takildi + 1 : 0;
    assert(takildi < 2, 'imleç ilerliyor: ' + imza);
    onceki = imza;
    if (c.cy >= 1) break;
  }
  assert(tur < 80, 'çevrim tamamlandı');
  assert.equal(await sapma(), 0, 'bir çevrim sonunda bütün eski sapma onarıldı (' + (tur + 1) + ' çalışma)');
  const cu = await one('select last_day, last_player, cycles::int cy, last_done_at is not null od from score_reconcile_daily_cursor');
  assert(cu.last_day === null && cu.last_player === null && cu.cy === 1 && cu.od, 'çevrim sonu: imleç başa sarar');
  assert((await one('select count(*)::int c from score_reconcile_log where remaining_count = 0 and from_day = $1::date', ['-infinity'])).c >= 1, 'günlükte ilerleme satırı');
  // Onarım bütçesi 1: her çağrı en çok 1 çift onarır, yine de biter.
  await kur();
  let c2 = {next_day: null, next_player: null}, say = 0, toplamOnarim = 0;
  for (; say < 120; say++) {
    const r = await one('select * from public.reconcile_player_score_daily_full($1, $2, 4, 1)', [c2.next_day, c2.next_player]);
    assert(r.drift_count <= 1, 'çağrı başına en çok 1 onarım');
    toplamOnarim += r.drift_count;
    c2 = r;
    if (r.done) break;
  }
  assert(c2.done && say < 120, 'elle tam geri doldurma biter');
  assert(toplamOnarim >= 5);
  assert.equal(await sapma(), 0, 'elle tam geri doldurma sonunda sapma yok');
  // Kalıcı hata: imleci takmaz, failures'a yazar; sonraki çevrimde (hata kalkınca) düzelir ve silinir.
  await db.query("update player_score_daily set score = score + 4 where player_id=$1 and day='-infinity'", [U(13)]);
  await db.exec(`create function boom_fn() returns trigger language plpgsql as $$ begin
      if (case when tg_op = 'DELETE' then old.player_id else new.player_id end) = '${U(13)}' then raise exception 'boom'; end if;
      if tg_op = 'DELETE' then return old; end if; return new; end $$;
    create trigger boom before insert or update or delete on player_score_daily
      for each row execute function boom_fn();`);
  const rb = await one('select * from public.reconcile_player_score_daily_full(null, null, 1000, 1000)');
  assert(rb.failed_count >= 1 && rb.done, 'kalıcı hata sayıldı, tarama yine de bitti');
  assert.equal((await one('select count(*)::int c from score_reconcile_failures where player_id=$1', [U(13)])).c, 1);
  await db.exec('drop trigger boom on player_score_daily');
  await db.query('select * from public.reconcile_player_score_daily_full(null, null, 1000, 1000)');
  assert.equal(await sapma(), 0);
  assert.equal((await one('select count(*)::int c from score_reconcile_failures where player_id=$1', [U(13)])).c, 0, 'hata kaydı onarımla silindi');
  // İstemci rolleri çağıramaz.
  for (const f of ['reconcile_player_score_daily_full(date,uuid,integer,integer)', 'reconcile_player_score_daily_sweep(integer,integer)', 'process_tournament_expiry()']) {
    assert.equal((await one(`select has_function_privilege('authenticated', 'public.${f}', 'execute') a, has_function_privilege('anon', 'public.${f}', 'execute') b, has_function_privilege('service_role', 'public.${f}', 'execute') c`)).a, false);
  }
  console.log('B: kalıcı imleç ' + (tur + 1) + ' çalışmada çevrim bitirdi, elle tam geri doldurma ' + (say + 1) + ' parçada, kalıcı hata takmadı');
}

// (D) turnuva: okuma kilitsiz, cron ilerletir
{
  const d = await defOnce(IMZA.bracket);
  assert(!d.includes('resolve_expired_tournament_matches') && !d.includes('start_due_tournaments') && !/\bperform\b/.test(d), 'bracket okuması yan etkisiz');
  assert(d.includes("'p1_submitted_at'") && d.includes("'serverScored'") && d.includes("'entryCount'"), 'bracket çıktı alanları durdu');
  assert.equal(JSON.stringify(await bracketAs(5)), brSnapOnce, 'bracket çıktısı göç öncesiyle birebir aynı (süre dolumu olmayan veri)');
  await turnuva(1, 'running', [9, 10, 11, 12], [
    {s: 0, a: 9, b: 10, sa: 8, suba: 1, dl: -3},
    {s: 1, a: 11, b: 12, dl: -3}], {started: new Date()});
  await turnuva(4, 'running', [13, 14], [{s: 0, a: 13, b: 14, dl: -3}], {started: new Date()});
  await turnuva(6, 'open', [15, 16], [], {opened: new Date(Date.now() - 3 * 86400 * 1000)});
  await turnuva(7, 'running', [17, 18], [{s: 0, a: 17, b: 18, dl: 5}], {started: new Date()});
  const br = await bracketAs(13);
  assert.equal(br.status, 'active', 'okuma süre dolumunu yürütmedi');
  assert.equal((await one('select status from tournament_matches where tournament_id=$1', [TID(4)])).status, 'pending');
  assert.equal((await one('select status from tournaments where id=$1', [TID(4)])).status, 'running');
  assert.equal((await one('select status from tournaments where id=$1', [TID(6)])).status, 'open');
  const t3 = await one('select * from tournaments where id=$1', [TID(3)]);
  await db.query('select public.process_tournament_expiry()');
  // T1: p9 gönderdi -> maç p9'a; öteki maç kimsesiz; tur bitti -> p9 şampiyon.
  const t1 = await one('select status, champion_id::text c from tournaments where id=$1', [TID(1)]);
  assert.equal(t1.status, 'finished'); assert.equal(t1.c, T(9));
  const t4 = await one('select status, champion_id from tournaments where id=$1', [TID(4)]);
  assert.equal(t4.status, 'finished'); assert.equal(t4.champion_id, null);
  assert.equal((await one('select status from tournaments where id=$1', [TID(6)])).status, 'running', 'dolum süresi geçen turnuva başladı');
  assert((await one('select count(*)::int c from tournament_matches where tournament_id=$1', [TID(6)])).c >= 1);
  // T2 (son turu bitmemiş) ve T7 (süresi gelmemiş) ilerletilmedi.
  assert.equal((await one('select count(*)::int c from tournament_matches where tournament_id=$1 and round=2', [TID(2)])).c, 0);
  assert.equal((await one('select status from tournament_matches where tournament_id=$1', [TID(7)])).status, 'pending');
  // Geçmişte bitmiş turnuva dokunulmadı.
  assert.deepEqual(await one('select * from tournaments where id=$1', [TID(3)]), t3);
  assert.deepEqual((await one("select proconfig from pg_proc where proname = 'resolve_expired_tournament_matches'")).proconfig, ['search_path=public']);
  const j = await one("select schedule, command from cron.job where jobname='tournament-expiry'");
  assert.equal(j.schedule, '* * * * *'); assert(j.command.includes('process_tournament_expiry'));
  assert((await one("select command from cron.job where jobname='reconcile-player-score-daily-sweep'")).command.includes('20000'));
  await as(0);
  console.log('D: bracket okuması yan etkisiz; cron süre dolumunu yalnız çalışan turnuvalarda ilerletir');
}

// ======================= Güvenlik / yedek / geri alma =======================
{
  for (const v of Object.values(IMZA)) {
    const p = await one(`select prosecdef, proconfig, has_function_privilege('anon', p.oid, 'execute') a, has_function_privilege('public', p.oid, 'execute') b from pg_proc p where p.oid = 'public.${v}'::regprocedure`);
    assert(p.prosecdef && p.proconfig && !p.a && !p.b, v);
  }
  const ya = (await db.query("select ad, tanim from olcek_tur3_yedek where ad like 'tur6:%'")).rows;
  assert.equal(ya.length, 4);
  for (const y of ya) assert(/-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$/.test(y.tanim), 'yedek iki md5 taşır: ' + y.ad);
  const yamali = {};
  for (const [k, v] of Object.entries(IMZA)) yamali[k] = await defOnce(v);
  const yedekler = (await db.query('select * from olcek_tur3_yedek')).rows;

  // Ya hep ya hiç: tek yedek eksik -> hiçbir şey dönmez.
  await db.exec("delete from olcek_tur3_yedek where ad = 'tur6:public.get_tournament_bracket()'");
  await assert.rejects(db.exec(geri), /yedek satırı yok/); await kapat();
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOnce(v), yamali[k], 'eksik yedekte ' + k + ' dönmedi');
  await db.query("insert into olcek_tur3_yedek select * from unnest($1::text[], $2::text[], $3::timestamptz[]) on conflict do nothing",
    [yedekler.map(y => y.ad), yedekler.map(y => y.tanim), yedekler.map(y => y.alindi)]);
  // Bozuk md5 zinciri.
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:', '-- md5:0') where ad like 'tur6:%'");
  await assert.rejects(db.exec(geri), /bozuk/); await kapat();
  await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:0', '-- md5:') where ad like 'tur6:%'");
  // Uygulanmış dalda yedek yoksa ileri göç durur.
  const kopya = (await db.query("select * from olcek_tur3_yedek where ad like 'tur6:%'")).rows;
  await db.exec("delete from olcek_tur3_yedek where ad like 'tur6:%'");
  await assert.rejects(uygula(), /yedek satırı\/md5 zinciri sağlam değil|yaratılacak nesnelerden biri zaten var/); await kapat();
  for (const y of kopya) await db.query('insert into olcek_tur3_yedek values ($1,$2,$3)', [y.ad, y.tanim, y.alindi]);
  // Beklenmeyen canlı gövde: ileri göç durur, hiçbir şey (yeni tablo dahil) kalmaz.
  await db.exec("create or replace function public.reconcile_player_score_total(p_days integer default 2, p_slice integer default 1000) returns integer language sql security definer set search_path to 'public', 'pg_temp' as $$ select 0 $$");
  await assert.rejects(uygula(), /ne bilinen canlı taban ne de/); await kapat();
  await db.exec('drop function public.reconcile_player_score_total(integer, integer)');
  await db.exec(yamali.toplam);
  await db.exec('revoke all on function public.reconcile_player_score_total(integer, integer) from public, anon, authenticated');
  // Göçten sonra gövde değişmişse geri alma durur.
  await db.exec(yamali.coz.replace("t.status = 'running'", "t.status = 'running' and true"));
  await assert.rejects(db.exec(geri), /canlı gövdesi göçten sonra değişmiş/); await kapat();
  await db.exec(yamali.coz);
  // Sızdıran yedek ACL'i: ileri göç durur.
  await db.exec('create role baska; grant select on olcek_tur3_yedek to baska');
  await assert.rejects(uygula(), /relacl/); await kapat();
  await db.exec('revoke all on olcek_tur3_yedek from baska');
  // İşlev yoksa yeniden yaratma yok.
  await db.exec('drop function public.get_tournament_bracket()');
  await assert.rejects(db.exec(geri), /yok; geri alma durdu/); await kapat();
  await db.exec(yamali.bracket);
  await db.exec('revoke all on function public.get_tournament_bracket() from public, anon; grant execute on function public.get_tournament_bracket() to authenticated');
  await uygula(); // sağlam yamalı durumda sorunsuz

  // Geri alma: eski gövdeler birebir, yeni nesneler gitti.
  await db.exec(geri);
  for (const [k, v] of Object.entries(IMZA)) assert.equal(await defOnce(v), tabanDef[k], 'geri alma birebir: ' + k);
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur6:%'")).c, 0);
  assert.equal((await one("select count(*)::int c from cron.job where jobname in ('tournament-expiry','reconcile-player-score-daily-sweep')")).c, 0);
  assert.equal((await one("select to_regprocedure('public.process_tournament_expiry()') t")).t, null);
  assert.equal((await one("select to_regclass('public.score_reconcile_daily_cursor') t")).t, null);
  assert.equal((await one("select to_regclass('public.tournament_matches_open_deadline_idx') t")).t, null);
  assert.equal((await one("select to_regprocedure('public.reconcile_player_score_daily_full(date,uuid,integer,integer)') t")).t, null);
  // Uygulanmamışken aynı adlı cron işi zaten varsa ileri göç onu ezmez, durur.
  await db.exec("select cron.schedule('tournament-expiry', '* * * * *', 'select 1')");
  await assert.rejects(uygula(), /yaratılacak nesnelerden biri zaten var/); await kapat();
  await db.exec("select cron.unschedule('tournament-expiry')");
  await uygula(); // yeniden ileri
  assert.equal((await one("select count(*)::int c from olcek_tur3_yedek where ad like 'tur6:%'")).c, 4);
  console.log('yedek/md5 zinciri, ya hep ya hiç, beklenmeyen gövde, geri alma ve yeniden ileri doğru');
}
console.log('TAMAM');
