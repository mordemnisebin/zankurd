// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_olcek_tur4_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-05_olcek_tur4.sql için: (a) tüm zamanlar sıralamasının (get_leaderboard,
// get_my_leaderboard_rank, get_friends_leaderboard) göçten ÖNCE/SONRA birebir
// aynı çıktısı, (b) tetikleyici yolunda toplamın bakımı (ekleme, değişiklik,
// silme), mutabakatla onarım, (c) weekly_league_assign 30 sınırı, (d) yamalar
// idempotent, (e) geri alma eski gövdeleri birebir döndürür.
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
const tur4 = read('2026-11-05_olcek_tur4.sql');
const lig = read('2026-11-05_haftalik_lig.sql');
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const R = n => '20000000-0000-0000-0000-' + String(n).padStart(12, '0');
const defOnce = async n => (await db.query(`select pg_get_functiondef('public.${n}'::regprocedure) d`)).rows[0].d;

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  create table profiles(id uuid primary key, display_name text, avatar_icon text,
    avatar_color text, avatar_url text, avatar_frame text, showcase_title text, xp bigint default 0);
  create table blocked_users(blocker_id uuid, blocked_id uuid);
  create table friends(user_id uuid, friend_id uuid);
  create table rooms(id uuid primary key default gen_random_uuid(), status text,
    ended_reason text, finished_at timestamptz, created_at timestamptz default now());
  create table room_players(room_id uuid, player_id uuid, score int, streak int);
  create table olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
`);
// Canlı taban: 11-04 ölçek göçünün sıralama bölümü (tablo, işlevler, tetikleyici).
const bas = olcek.indexOf('create table if not exists public.player_score_daily');
const son = olcek.indexOf('-- Günlük satırları (pencereye göre)');
await db.exec(olcek.slice(bas, son).replace(/revoke all[^;]*;/gi, '').replace(/grant execute[^;]*;/gi, '')
  .replace(/alter table [^;]*enable row level security;/gi, '').replace(/create temp table olcek_baslangic[\s\S]*?\n\n/, 'create temp table olcek_baslangic as select clock_timestamp() as t;\n\n'));
for (const n of ['leaderboard_daily_rows', 'get_leaderboard', 'get_friends_leaderboard']) await db.exec(fnText(olcek, n));
await db.exec(fnText(tur3, 'get_my_leaderboard_rank'));
await db.exec(noRevokeFix(tur3.slice(tur3.indexOf('create table if not exists public.score_reconcile_log'), tur3.indexOf('-- Son p_days İstanbul'))));
await db.exec(fnText(tur3, 'reconcile_player_score_daily'));
function noRevokeFix(t) { return t.replace(/revoke all[^;]*;/gi, '').replace(/alter table [^;]*enable row level security;/gi, ''); }
// Haftalık lig tabanı: tablolar + işlevler (bölüm 4 ve cron hariç).
await db.exec(lig.slice(lig.indexOf('create table if not exists public.weekly_league_cohorts'), lig.indexOf('-- 4. İstemci RPC')).replace(/-- -+\n$/, '')
  .replace(/revoke all[^;]*;/gi, '').replace(/alter table [^;]*enable row level security;/gi, ''));

// --- Veri: eşitlikler bol, engelleme, arkadaşlık, birkaç gün ---------------
let seed = 11;
const rnd = n => (seed = (seed * 1103515245 + 12345) % 2147483648) % n;
const N = 50;
for (let i = 1; i <= N; i++) await db.query('insert into profiles(id, display_name, xp) values ($1,$2,$3)', [U(i), i % 9 === 0 ? null : 'P' + i, rnd(500)]);
for (let i = 1; i <= 6; i++) await db.query('insert into blocked_users values ($1,$2)', [U(1 + rnd(N)), U(1 + rnd(N))]);
for (let i = 1; i <= 80; i++) await db.query('insert into friends values ($1,$2)', [U(1 + rnd(N)), U(1 + rnd(N))]);
let rid = 0;
const finishRoom = async (daysAgo, ended, pls) => {
  const id = R(++rid);
  await db.query("insert into rooms(id,status,ended_reason,finished_at) values ($1,'active',$2,null)", [id, ended]);
  for (const [p, sc, st] of pls) await db.query('insert into room_players values ($1,$2,$3,$4)', [id, U(p), sc, st]);
  await db.query("update rooms set status='finished', finished_at = now() - ($2::int * interval '1 day') - interval '1 hour' where id=$1", [id, daysAgo]);
  return id;
};
for (let k = 0; k < 90; k++) {
  const a = 1 + rnd(N), b = 1 + ((a + rnd(N - 1)) % N);
  await finishRoom(rnd(45), rnd(6) === 0 ? 'abandoned' : null, [[a, rnd(4) * 50, rnd(3)], [b, rnd(4) * 50, rnd(3)]]);
}
// finished_at boş (-infinity) kovası da tüm zamanlara girer.
{
  const id = R(++rid);
  await db.query("insert into rooms(id,status,ended_reason,finished_at) values ($1,'active',null,null)", [id]);
  await db.query('insert into room_players values ($1,$2,70,5)', [id, U(3)]);
  await db.query("update rooms set status='finished' where id=$1", [id]);
}
assert((await db.query('select count(*)::int c from player_score_daily')).rows[0].c > 40, 'günlük satırlar var');

const snapshot = async () => {
  const out = {};
  for (const days of [-1, 0, 7, 30]) {
    out['lb' + days] = (await db.query('select * from get_leaderboard($1, 100)', [days])).rows;
    for (let i = 1; i <= N + 1; i++) {
      await db.exec(`select set_config('test.uid', '${i <= N ? U(i) : ''}', false)`);
      out[`rank${days}_${i}`] = (await db.query('select * from get_my_leaderboard_rank($1)', [days])).rows;
      out[`fr${days}_${i}`] = (await db.query('select * from get_friends_leaderboard($1)', [days])).rows;
    }
  }
  return out;
};
const oncesi = await snapshot();
const eskiDefs = {};
for (const n of ['leaderboard_daily_rows(integer,uuid[])', 'recompute_player_score_day(uuid,date)', 'rebuild_player_score_daily(date)',
  'reconcile_player_score_daily(integer)', 'weekly_league_assign(uuid,date)']) eskiDefs[n] = await defOnce(n);

// --- Göç: PGlite için rol/RLS/cron uyarlaması, kendisi değişmeden ------------
const uygula = () => db.exec(tur4.replace(/alter table [^;]*enable row level security;/gi, ''));
await uygula();
await uygula(); // idempotent: ikinci koşu hata vermez, yedek ve gövde değişmez
assert.equal((await db.query("select count(*)::int c from olcek_tur3_yedek where ad like 'tur4:%'")).rows[0].c, 5, '5 yedek');
assert((await db.query("select tanim from olcek_tur3_yedek where ad like 'tur4:public.leaderboard%'")).rows[0].tanim.includes('-- md5:'), 'yedek md5 taşır');
console.log('göç iki kez uygulandı (idempotent)');

// (a) Denklik
const sonrasi = await snapshot();
let kontrol = 0;
for (const k of Object.keys(oncesi)) { assert.deepEqual(sonrasi[k], oncesi[k], k); kontrol++; }
assert((await db.query('select count(*)::int c from player_score_total')).rows[0].c > 20, 'toplam dolu');
console.log('sıralama denkliği: ' + kontrol + ' sorgu göç öncesiyle birebir aynı');
// Tüm zamanlar artık toplam tablosundan okunur: günlük tablo değişse -1 etkilenmez.
{
  const kopya = (await db.query('select count(*)::int c from player_score_total')).rows[0].c;
  const farkli = (await db.query(`select count(*)::int c from (
    select player_id, sum(score), max(streak), sum(rooms) from player_score_daily group by 1
    except select player_id, score, streak, rooms from player_score_total) x`)).rows[0].c;
  assert.equal(farkli, 0, 'toplam = günlük toplamı');
  assert(kopya > 0);
}

// (b) Tetikleyici yolu: bitir, değiştir, sil; toplam her seferinde günlük toplamına eşit.
const tutarli = async msg => {
  const f = (await db.query(`select count(*)::int c from (
    (select player_id, sum(score)::bigint s, max(streak)::bigint t, sum(rooms)::bigint r from player_score_daily group by 1
     except select player_id, score, streak, rooms from player_score_total)
    union all
    (select player_id, score, streak, rooms from player_score_total
     except select player_id, sum(score)::bigint, max(streak)::bigint, sum(rooms)::bigint from player_score_daily group by 1)) x`)).rows[0].c;
  assert.equal(f, 0, msg);
};
await tutarli('göç sonrası');
const yeni = await finishRoom(0, null, [[1, 500, 9], [2, 40, 1]]);
await tutarli('oda bitti');
assert.equal(+(await db.query('select streak from player_score_total where player_id=$1', [U(1)])).rows[0].streak >= 9, true, 'en iyi seri max');
await db.query("update rooms set ended_reason='abandoned' where id=$1", [yeni]);
await tutarli('oda iptal edildi (seri düştü)');
await db.query("update rooms set ended_reason=null, finished_at = now() - interval '3 days' where id=$1", [yeni]);
await tutarli('oda başka güne taşındı');
for (const p of [1, 2]) await db.query('delete from player_score_daily where player_id=$1', [U(p)]); // sapma yarat
await db.query('update player_score_total set score = score + 1 where player_id = $1', [U(5)]);
await db.query('insert into player_score_total(player_id, score) select $1, 7 where not exists (select 1 from player_score_total where player_id=$1)', [U(1)]);
// Mutabakat: günlük satırlar yeniden kurulur, toplamlar eşitlenir.
await db.exec('select public.rebuild_player_score_daily(null)');
await tutarli('onarım aracı toplamı da kurar');
await db.query('update player_score_total set score = score + 99 where player_id = $1', [U(7)]);
await db.query("update player_score_total set updated_at = now() where player_id = $1", [U(7)]);
await finishRoom(0, null, [[10, 60, 2], [11, 20, 0]]); // bugün: mutabakat penceresinde
await db.query('delete from player_score_total where player_id = $1', [U(10)]); // eksik toplam
await db.query('update player_score_total set rooms = 99 where player_id = $1', [U(11)]); // sapmış toplam
assert.equal((await db.query('select public.reconcile_player_score_total(2) n')).rows[0].n >= 1, true);
await db.query('select public.reconcile_player_score_daily(2)');
await tutarli('gecelik mutabakat toplamı onarır');
console.log('toplam bakımı (ekleme/iptal/taşıma/onarım/mutabakat) tutarlı');

// (b2) Dönen imleç: pencere DIŞINDAKİ eski sapma ve eksik eski toplam döngüde yakalanır.
{
  await db.exec("update player_score_total set score = score + 5, updated_at = now() - interval '30 days' where player_id = '" + U(20) + "'");
  await db.exec("delete from player_score_total where player_id = '" + U(21) + "'");
  const eskiGun = (await db.query('select count(*)::int c from player_score_daily where player_id in ($1,$2) and day < current_date - 5', [U(20), U(21)])).rows[0].c;
  assert(eskiGun > 0, 'test verisi: 20/21 eski günlük satır taşır');
  let tur = 0;
  for (; tur < 200; tur++) { // dilim 3 oyuncu: tüm oyuncular birkaç turda dolaşılır
    await db.query('select public.reconcile_player_score_total(2, 3)');
    const f = (await db.query(`select count(*)::int c from (
      select player_id, sum(score)::bigint, max(streak)::bigint, sum(rooms)::bigint from player_score_daily group by 1
      except select player_id, score, streak, rooms from player_score_total) x`)).rows[0].c;
    if (f === 0) break;
  }
  assert(tur < 200 && tur > 0, 'dönen imleç eski sapmayı yakaladı (tur ' + tur + ')');
  await tutarli('dönen imleç sonrası');
  console.log('dönen imleç: eski sapma ve eksik eski toplam ' + (tur + 1) + ' turda düzeldi');
  // Kilitli parçalı yeniden kurma: oyuncu artan sırada, sonuna kadar.
  await db.exec("update player_score_total set score = score + 1");
  await db.exec('select public.rebuild_player_score_total_all()');
  await tutarli('parçalı yeniden kurma');
}
// (b3) Yama koruması: yarım yama / çift bağlayıcı göçü durdurur; yedek GÜNCEL gövde.
{
  const kapat = async () => { try { await db.exec('rollback'); } catch (e) {} };
  const sig = 'public.leaderboard_daily_rows(integer,uuid[])';
  const d = await defOnce('leaderboard_daily_rows(integer,uuid[])');
  // Yeni parça var ama eski parça da duruyor (yarım yama): durmalı.
  await db.exec(d.replace('  union all\n  select t.player_id', '  union all\n  select a.player_id, a.score, a.streak, a.rooms from public.player_score_daily a, edge e where (e.ts is null or a.day > e.d)\n  union all\n  select t.player_id'));
  await assert.rejects(uygula(), /bağlayıcı durumu beklenmiyor/);
  await kapat();
  await db.exec(d);
  await uygula();
  const y = (await db.query("select tanim from olcek_tur3_yedek where ad = 'tur4:" + sig + "'")).rows[0].tanim;
  assert(/-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$/.test(y), 'yedek iki md5 taşır');
  // Göçten sonra gövde değişmişse geri alma durur.
  await db.exec(d.replace('select t.player_id, t.score', 'select t.player_id, t.score + 0'));
  await assert.rejects(db.exec(read('geri_al/2026-11-05_olcek_tur4_geri.sql')), /göçten sonra değişmiş/);
  await kapat();
  await db.exec(d);
  console.log('yama koruması ve geri alma md5 doğrulaması doğru');
}
// (c) weekly_league_assign: 30 sınırı, tekrar çağrı aynı küme.
{
  await db.exec('insert into profiles(id) select (\'30000000-0000-0000-0000-\' || lpad(g::text, 12, \'0\'))::uuid from generate_series(1, 75) g');
  const hafta = (await db.query("select public.weekly_league_week_start() w")).rows[0].w;
  const ids = (await db.query("select id from profiles where id::text like '30000000%' order by id")).rows.map(r => r.id);
  const ilk = {};
  for (const id of ids) ilk[id] = (await db.query('select public.weekly_league_assign($1, $2) c', [id, hafta])).rows[0].c;
  for (const id of ids) assert.equal((await db.query('select public.weekly_league_assign($1, $2) c', [id, hafta])).rows[0].c, ilk[id], 'aynı küme');
  const k = (await db.query('select id, member_count from weekly_league_cohorts order by created_at, id')).rows;
  assert.equal(k.length, 3, '75 oyuncu = 30+30+15'); assert.deepEqual(k.map(x => x.member_count), [30, 30, 15]);
  for (const c of k) assert.equal((await db.query('select count(*)::int n from weekly_league_members where cohort_id=$1', [c.id])).rows[0].n, c.member_count);
  const a = await defOnce('weekly_league_assign(uuid,date)');
  assert(a.includes('for update skip locked') && a.includes("'league-cohort-create:'") && !a.includes("'league-cohort:'"), 'kilit daraltıldı');
  console.log('lig ataması: 30/30/15, tekrar çağrı aynı küme, kilit daraltıldı');
}

// (d) Beklenmeyen canlı gövde: göç durur.
{
  await db.exec("create or replace function public.weekly_league_assign(p_player_id uuid, p_week date) returns uuid language sql as $$ select null::uuid $$");
  await db.exec("delete from olcek_tur3_yedek where ad like 'tur4:public.weekly%'");
  await assert.rejects(uygula(), /bağlayıcı durumu beklenmiyor/);
  await db.exec('rollback');
  await db.exec(eskiDefs['weekly_league_assign(uuid,date)']);
  await uygula(); // gövde geri gelince göç ilerler
}

// (e) Geri alma eski gövdeleri birebir döndürür.
{
  const gerider = await snapshot();
  await db.exec(read('geri_al/2026-11-05_olcek_tur4_geri.sql'));
  for (const [n, d] of Object.entries(eskiDefs)) assert.equal(await defOnce(n), d, 'geri alma: ' + n);
  assert.equal((await db.query("select to_regclass('public.player_score_total') t")).rows[0].t, null, 'tablo kalktı');
  await db.exec(read('geri_al/2026-11-05_olcek_tur4_geri.sql')); // idempotent
  assert.deepEqual(await snapshot(), gerider, 'geri alma sonrası çıktı geri almadan önceyle aynı');
  console.log('geri alma eski gövdeleri birebir döndürdü; sıralama çıktısı aynı');
}
console.log('TAMAM');
