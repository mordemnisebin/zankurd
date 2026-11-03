// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_olcek_tur3_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-05_olcek_tur3.sql için: (a) get_my_leaderboard_rank eski/yeni sıra
// denkliği (eşitlik kırma dahil), (b) join_matchmaking ve cleanup_stale_rooms
// yamaları yamalanıp derlenir, (c) mutabakat + saklama işlevleri çalışır.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const olcek = read('2026-11-04_olcek_sertlestirme.sql');
const tur3 = read('2026-11-05_olcek_tur3.sql');
const sunucu = read('2026-10-24_sunucu_sertlestirme.sql');
const oda = read('2026-10-18_oda_kod_kategori.sql');
const kalabalik = read('2026-10-16_kalabalik_oda.sql');
const noRevoke = t => t.replace(/revoke all[^;]*;/gi, '').replace(/alter table [^;]*enable row level security;/gi, '');
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');

await db.exec(`
  create schema auth;
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  create table profiles(id uuid primary key, display_name text, avatar_icon text,
    avatar_color text, avatar_url text, avatar_frame text, showcase_title text);
  create table blocked_users(blocker_id uuid, blocked_id uuid);
  create table rooms(id uuid primary key default gen_random_uuid(), status text,
    ended_reason text, finished_at timestamptz, created_at timestamptz default now());
  create table room_players(room_id uuid, player_id uuid, score int, streak int);
  create table player_score_daily(player_id uuid not null references profiles(id) on delete cascade,
    day date not null, score bigint not null default 0, streak bigint not null default 0,
    rooms bigint not null default 0, primary key(player_id, day));
  create table rate_limit_events(user_id uuid, bucket text, created_at timestamptz default now());
  create table push_outbox(id uuid default gen_random_uuid(), delivery_status text, created_at timestamptz);
`);
await db.exec(fnText(olcek, 'score_day_of'));
await db.exec(fnText(olcek, 'recompute_player_score_day'));
await db.exec(fnText(olcek, 'leaderboard_daily_rows'));
await db.exec(fnText(olcek, 'get_my_leaderboard_rank').replace('get_my_leaderboard_rank', 'rank_eski'));
await db.exec(fnText(tur3, 'get_my_leaderboard_rank').replace('get_my_leaderboard_rank', 'rank_yeni'));

// (a) Eski/yeni sıra denkliği: eşitlikler bilerek bol (az sayıda farklı değer).
let seed = 7;
const rnd = n => (seed = (seed * 1103515245 + 12345) % 2147483648) % n;
const N = 60;
for (let i = 1; i <= N; i++) await db.query('insert into profiles(id, display_name) values ($1, $2)', [U(i), i % 7 === 0 ? null : 'P' + i]);
for (let i = 1; i <= N; i++) {
  for (let d = 0; d < 1 + rnd(4); d++) {
    await db.query(`insert into player_score_daily values ($1, current_date - $2::int, $3, $4, $5)
      on conflict do nothing`, [U(i), d, rnd(4) * 100, rnd(3), 1 + rnd(2)]);
  }
}
for (let i = 1; i <= 8; i++) await db.query('insert into blocked_users values ($1,$2)', [U(1 + rnd(N)), U(1 + rnd(N))]);
let kontrol = 0;
for (const days of [-1, 0, 3, 30]) {
  for (let i = 1; i <= N + 1; i++) {
    await db.exec(`select set_config('test.uid', '${i <= N ? U(i) : ''}', false)`);
    const a = (await db.query('select * from rank_eski($1)', [days])).rows;
    const b = (await db.query('select * from rank_yeni($1)', [days])).rows;
    assert.deepEqual(b, a, `p_days=${days} oyuncu ${i}`);
    kontrol++;
  }
}
console.log('sira denkligi: ' + kontrol + ' sorgu ayni');

// (b) Yamalar: canlı gövde = 10-18 / 10-24 gövdesi + 11-04 yamaları.
const joinSrc = fnText(oda, 'join_matchmaking').replace(/^create or replace function public\.join_matchmaking/i, 'create or replace function public.join_matchmaking');
const cleanupSrc = fnText(sunucu, 'cleanup_stale_rooms');
const yamalar = [...olcek.matchAll(/select pg_temp\.olcek_yama\(\s*'public\.(join_matchmaking\(text\)|cleanup_stale_rooms\(\))'[\s\S]*?\);\n/g)].map(m => m[0]);
assert.equal(yamalar.length, 3, 'olcek yamalari (join 2 + cleanup 1)');
await db.exec(fnText(kalabalik, 'touch_matchmaking'));
await db.exec(fnText(olcek, 'on_room_score_daily'));
await db.exec(joinSrc);
await db.exec(cleanupSrc);
{
  const yamaFn = olcek.slice(olcek.indexOf('create or replace function pg_temp.olcek_yama'), olcek.indexOf('$yama$;') + 7);
  await db.exec('begin;' + yamaFn + yamalar.join('\n') + 'commit;');
}
const yamaBas = tur3.indexOf('create or replace function pg_temp.tur3_yama');
const yamaSon = tur3.indexOf('$yama2$;', yamaBas) + 8;
const sadeYama = tur3.slice(yamaBas, yamaSon);
const joinBas = tur3.indexOf("select pg_temp.tur3_yama(\n  'public.join_matchmaking(text)'");
const joinYamalari = tur3.slice(joinBas, tur3.indexOf('-- ---', joinBas));
const trigBas = tur3.indexOf("select pg_temp.tur3_yama2(\n  'public.on_room_score_daily()'");
const trigYama = tur3.slice(trigBas, tur3.indexOf('-- ---', trigBas));
const cleanupYama = tur3.slice(tur3.indexOf('-- Lobi: greatest'), tur3.indexOf('-- Küçük, sıcak tablo'));
const defOnce = async n => (await db.query(`select pg_get_functiondef('public.${n}'::regprocedure) d`)).rows[0].d;
const joinEski = await defOnce('join_matchmaking(text)');
const cleanupEski = await defOnce('cleanup_stale_rooms()');
const touchEski = await defOnce('touch_matchmaking()');
const trigEski = await defOnce('on_room_score_daily()');
const calistir = async () => db.exec('begin;' + sadeYama + joinYamalari + cleanupYama + trigYama + 'commit;');
try { await calistir(); } catch (e) { const q = e.internalQuery || ''; const k = +e.internalPosition; console.error(e.message, '\n', q.slice(Math.max(0, k - 400), k + 100)); process.exit(1); }
await calistir(); // idempotent: ikinci çalışma değiştirmez
const j = (await db.query("select pg_get_functiondef('public.join_matchmaking(text)'::regprocedure) d")).rows[0].d;
assert(j.includes('v_pass := v_pass + 1'), 'join: iki gecis');
assert(j.includes('perform pg_sleep(0.03)'), 'join: kilitli aday yeniden deneme');
const tc = await defOnce('touch_matchmaking()');
assert(!tc.includes("perform pg_advisory_xact_lock"), 'touch kategori kilidi almaz');
const tg = await defOnce('on_room_score_daily()');
assert(tg.includes('order by rp.player_id') && tg.includes('v_old_day > v_new_day'), 'tetikleyici sirali kilit');
assert(j.includes('for update skip locked\n  );'), 'join: bayat silme skip locked');
assert((j.match(/pg_advisory_xact_lock\(hashtextextended\('matchmaking:'/g) || []).length === 1, 'kategori kilidi tek (ikinci gecis)');
assert(j.indexOf("matchmaking:' || lower") > j.indexOf('v_pass = 1'), 'kilit ikinci gecisin icinde');
const c = (await db.query("select pg_get_functiondef('public.cleanup_stale_rooms()'::regprocedure) d")).rows[0].d;
assert(c.includes("r.created_at < now() - interval '30 minutes'"), 'cleanup lobi suzgeci');
assert(c.includes("coalesce(r.started_at, r.created_at) < now() - interval '10 minutes'"), 'cleanup aktif suzgeci');
console.log('join_matchmaking / cleanup_stale_rooms yamalari derlendi, 2. calisma degistirmedi');
{
  const geri = read('geri_al/2026-11-05_olcek_tur3_geri.sql');
  const g = geri.slice(geri.indexOf('create or replace function pg_temp.tur3_geri('), geri.indexOf('-- get_my_leaderboard_rank:'));
  await db.exec('begin;' + g + 'commit;');
  assert.equal(await defOnce('join_matchmaking(text)'), joinEski, 'geri alma join gövdesini birebir döndürür');
  assert.equal(await defOnce('cleanup_stale_rooms()'), cleanupEski, 'geri alma cleanup gövdesini birebir döndürür');
  assert.equal(await defOnce('touch_matchmaking()'), touchEski, 'geri alma touch gövdesini birebir döndürür');
  assert.equal(await defOnce('on_room_score_daily()'), trigEski, 'geri alma tetikleyici gövdesini birebir döndürür');
  await calistir(); // yeniden ileri
  console.log('geri alma yamalari eski govdeyi birebir dondurdu');
}

// (c) Mutabakat + saklama.
{
  const tabs = tur3.slice(tur3.indexOf('create table if not exists public.score_reconcile_log'), tur3.indexOf('-- Son p_days İstanbul'));
  await db.exec(noRevoke(tabs));
}
await db.exec(fnText(tur3, 'reconcile_player_score_daily'));
await db.exec('delete from player_score_daily');
const room = '20000000-0000-0000-0000-000000000001';
await db.query("insert into rooms(id,status,ended_reason,finished_at) values ($1,'finished','completed', now())", [room]);
await db.query('insert into room_players values ($1,$2,30,2),($1,$3,50,1),($1,$4,10,0)', [room, U(1), U(2), U(99)]); // U(99) profilsiz: FK hatası
await db.query('insert into player_score_daily values ($1, public.score_day_of(now()), 999, 0, 1)', [U(1)]); // sapma
await db.query("insert into player_score_daily values ($1, public.score_day_of(now()), 5, 0, 1)", [U(3)]);     // hayalet
assert.equal((await db.query('select public.reconcile_player_score_daily(2) n')).rows[0].n, 4, '4 sapma (yanlis, eksik, hayalet, FK)');
let log = (await db.query('select * from score_reconcile_log order by id desc limit 1')).rows[0];
assert.equal(log.drift_count, 4); assert.equal(log.failed_count, 1); assert.equal(log.remaining_count, 0);
assert.equal((await db.query('select count(*)::int c from score_reconcile_failures')).rows[0].c, 1, 'kalici hata kaydedildi');
assert.equal((await db.query('select public.reconcile_player_score_daily(2) n')).rows[0].n, 1, 'yalniz kalici hata kalir');
assert.deepEqual((await db.query('select score from player_score_daily order by score')).rows.map(r => r.score + ''), ['30', '50']);
console.log('mutabakat: sirali, kalici hata izole');
await db.exec(fnText(tur3, 'push_outbox_retention'));
await db.exec(fnText(tur3, 'rate_limit_events_sweep'));
await db.exec(`insert into push_outbox(delivery_status, created_at) values
  ('sent', now() - interval '20 days'), ('failed', now() - interval '20 days'),
  ('sent', now() - interval '1 day'), ('pending', now() - interval '30 days')`);
assert.equal((await db.query('select public.push_outbox_retention(14, 100) n')).rows[0].n, 2);
assert.equal((await db.query('select count(*)::int c from push_outbox')).rows[0].c, 2, 'pending ve taze satir kalir');
await db.exec(`insert into rate_limit_events(user_id, bucket, created_at) values
  ('${U(1)}','a', now() - interval '3 days'), ('${U(1)}','a', now())`);
assert.equal((await db.query('select public.rate_limit_events_sweep(100) n')).rows[0].n, 1);
console.log('mutabakat ve saklama islevleri dogru');
// (e) get_my_leaderboard_rank: taban doğrulama + yedek + geri alma.
{
  await db.exec(fnText(olcek, 'get_my_leaderboard_rank'));
  const eski = await defOnce('get_my_leaderboard_rank(integer)');
  const bas = tur3.indexOf('create table if not exists public.olcek_tur3_yedek');
  const bit = tur3.indexOf('create or replace function public.get_my_leaderboard_rank');
  const guard = noRevoke(tur3.slice(bas, bit));
  await db.exec(guard);
  assert.equal((await db.query('select count(*)::int c from olcek_tur3_yedek')).rows[0].c, 1, 'yedek alindi');
  await db.exec(fnText(tur3, 'get_my_leaderboard_rank'));
  await db.exec(guard); // yeni govdede: yedek degismez, hata yok
  assert.equal((await db.query('select tanim from olcek_tur3_yedek')).rows[0].tanim, eski, 'yedek eski govde');
  const geri = read('geri_al/2026-11-05_olcek_tur3_geri.sql');
  const rg = geri.slice(geri.indexOf('do $tur3_rank_geri$'), geri.indexOf('select cron.unschedule'));
  await db.exec(rg);
  assert.equal(await defOnce('get_my_leaderboard_rank(integer)'), eski, 'geri alma yedekten birebir');
  // Beklenmeyen canlı gövde: göç durur.
  await db.exec("drop function public.get_my_leaderboard_rank(integer); create function public.get_my_leaderboard_rank(p_days integer default -1) returns table(rank bigint) language sql as $$ select 1::bigint $$");
  await assert.rejects(db.exec(guard.replace(/insert into public\.olcek_tur3_yedek[\s\S]*?do nothing;/, '')), /beklenen tabanla eşleşmiyor/);
  console.log('rank taban dogrulama, yedek ve geri alma dogru');
}
// (d) touch_presence_v2: dokunuş + görünürlük tek çağrıda.
await db.exec(`create table user_presence(user_id uuid primary key, visible boolean not null default false,
  last_seen_at timestamptz, last_touch_at timestamptz)`);
await db.exec(fnText(tur3, 'touch_presence_v2').replace('security definer', ''));
await db.exec(`select set_config('test.uid', '${U(1)}', false)`);
const v2 = async () => (await db.query('select public.touch_presence_v2() v')).rows[0].v;
assert.equal(await v2(), false, 'satır yok: kapalı');
await db.exec(`insert into user_presence(user_id, visible) values ('${U(1)}', true)`);
assert.equal(await v2(), true, 'görünür: dokunur');
assert.ok((await db.query('select last_seen_at from user_presence')).rows[0].last_seen_at, 'last_seen_at yazıldı');
assert.equal(await v2(), true, '60 sn içinde tekrar: yine görünür, yazım yok');
await db.exec("update user_presence set visible = false, last_seen_at = null");
assert.equal(await v2(), false, 'kapalı: false, yazım yok');
assert.equal((await db.query('select last_seen_at from user_presence')).rows[0].last_seen_at, null);
console.log('touch_presence_v2 dogru');
console.log('TAMAM');
