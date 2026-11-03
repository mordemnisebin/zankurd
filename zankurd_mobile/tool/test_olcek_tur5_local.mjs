// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_olcek_tur5_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-05_olcek_tur5.sql için: (a) join_matchmaking yamalanır, ikinci çalışma
// değiştirmez; kilit altında pg_sleep YOK (kilit uykudan sonra); (b) eşleşme
// doğruluğu: iki sıradaki oyuncu TAM BİR kez eşleşir, üçüncü bekler, çift
// eşleşme yok; (c) get_my_league tek uçuş yamaları; (d) geri alma eski
// gövdeleri birebir döndürür; (e) beklenmeyen gövde göçü durdurur.
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
const tur5 = read('2026-11-05_olcek_tur5.sql');
const oda = read('2026-10-18_oda_kod_kategori.sql');
const lig = read('2026-11-05_haftalik_lig.sql');
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const as = n => db.exec(`select set_config('test.uid', '${U(n)}', false)`);
const defOnce = async n => (await db.query(`select pg_get_functiondef('public.${n}'::regprocedure) d`)).rows[0].d;
const join = async (n, cat = 'Rastgele') => { await as(n); return (await db.query('select public.join_matchmaking($1) r', [cat])).rows[0].r; };

await db.exec(`
  create role anon; create role authenticated;
  create schema auth;
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  create table profiles(id uuid primary key, display_name text);
  create table blocked_users(blocker_id uuid, blocked_id uuid);
  create table categories(id uuid primary key default gen_random_uuid(), name text, is_active boolean default true);
  create table rooms(id uuid primary key default gen_random_uuid(), code text unique, host_id uuid,
    category_id uuid, category_ids uuid[], question_count int, seconds_per_question int,
    status text, created_at timestamptz default now());
  create table room_players(room_id uuid, player_id uuid, is_ready boolean, left_at timestamptz,
    joined_at timestamptz default now());
  create table matchmaking_queue(player_id uuid primary key, category_name text not null,
    room_id uuid, joined_at timestamptz default now(), last_seen_at timestamptz);
  create function public.room_category_label(ids uuid[], n text) returns text language sql as $$ select n $$;
  create function public.start_room_game(p uuid) returns json language sql as $$ select json_build_object('question_count', 10) $$;
  create table olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
  create table weekly_league_members(week_start date, player_id uuid, cohort_id uuid, tier smallint, outcome text);
  create table weekly_league_closed(week_start date primary key);
`);
for (let i = 1; i <= 4; i++) await db.query('insert into profiles values ($1,$2)', [U(i), 'P' + i]);
await db.exec("insert into categories(name) values ('Ziman')");

// Canlı join gövdesi = 10-18 + 11-04 yamaları + 11-05 tur3 yamaları.
const noRevoke = t => t.replace(/revoke all[^;]*;/gi, '').replace(/alter table [^;]*enable row level security;/gi, '');
await db.exec(fnText(oda, 'join_matchmaking'));
const yamalar = [...olcek.matchAll(/select pg_temp\.olcek_yama\(\s*'public\.join_matchmaking\(text\)'[\s\S]*?\);\n/g)].map(m => m[0]);
assert.equal(yamalar.length, 2, 'olcek join yamalari');
const olcekFn = olcek.slice(olcek.indexOf('create or replace function pg_temp.olcek_yama'), olcek.indexOf('$yama$;') + 7);
await db.exec('begin;' + olcekFn + yamalar.join('\n') + 'commit;');
const yamaBas = tur3.indexOf('create or replace function pg_temp.tur3_yama');
const sadeYama = tur3.slice(yamaBas, tur3.indexOf('$yama2$;', yamaBas) + 8);
const joinBas = tur3.indexOf("select pg_temp.tur3_yama(\n  'public.join_matchmaking(text)'");
const joinYamalari = tur3.slice(joinBas, tur3.indexOf('-- touch_matchmaking: kategori kilidi kalktı', joinBas));
await db.exec('begin;' + sadeYama + joinYamalari + 'commit;');
await db.exec(fnText(lig, 'get_my_league'));
await db.exec(fnText(lig, 'weekly_league_rollover'));
const joinEski = await defOnce('join_matchmaking(text)');
const ligEski = await defOnce('get_my_league()');
assert(joinEski.includes('pg_sleep(0.03)') && joinEski.includes('v_pass = 1'), 'taban: tur3 gövdesi');

// (a) Tabanda kilit altında uyku var; yamadan sonra yok.
import crypto from 'node:crypto';
const md5 = t => crypto.createHash('md5').update(t).digest('hex');
if (process.env.TUR5_PRINT_MD5) { console.log(md5(joinEski), md5(ligEski)); process.exit(0); }
assert(tur5.includes(md5(joinEski)), 'göçteki join taban md5 = repo zincirinden türeyen gövde');
assert(tur5.includes(md5(ligEski)), 'göçteki lig taban md5 = repo zincirinden türeyen gövde');
const uygula = () => db.exec(tur5);
await uygula();
await uygula(); // idempotent
const j = await defOnce('join_matchmaking(text)');
assert(j.includes('pg_try_advisory_xact_lock(hashtextextended(\'matchmaking:\'') && !/\n    perform pg_advisory_xact_lock\(hashtextextended\('matchmaking:'/.test(j.slice(j.indexOf('v_locked'))), 'kategori kilidi try-lock');
const lockIdx = j.indexOf("pg_try_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name)");
const sleepIdx = j.indexOf('perform pg_sleep(0.03)');
assert(lockIdx > 0 && sleepIdx > 0 && sleepIdx < lockIdx, 'uyku kilitten ÖNCE');
assert.equal((j.match(/pg_sleep/g) || []).length, 1, 'tek uyku');
assert(j.includes('v_locked := true') && j.includes('not v_locked'), 'kilit bir kez');
assert.equal((j.match(/pg_try_advisory_xact_lock\(hashtextextended\('matchmaking:'/g) || []).length, 1);
assert(!/[^_]pg_advisory_xact_lock\(hashtextextended\('matchmaking:'/.test(j), 'bekleyen kategori kilidi kalmadı');
const l = await defOnce('get_my_league()');
assert(l.includes("pg_try_advisory_xact_lock") && l.includes("'league-rollover:' || (v_week - 7)::text"), 'lig tek uçuş');
assert(l.includes('not v_pending'), 'lig: bekleyen kapanışta atama yok');
assert.equal((await db.query("select count(*)::int c from olcek_tur3_yedek where ad like 'tur5:%'")).rows[0].c, 2);
console.log('tur5 yamalari derlendi, 2. calisma degistirmedi');

// (b) Eşleşme doğruluğu.
const r1 = await join(1); assert.equal(r1.status, 'waiting');
const r2 = await join(2); assert.equal(r2.status, 'matched', 'ikinci oyuncu eşleşir');
const r3 = await join(3); assert.equal(r3.status, 'waiting', 'üçüncü bekler');
assert.equal((await db.query('select count(*)::int c from rooms')).rows[0].c, 1, 'tek oda');
assert.equal((await db.query('select count(*)::int c from room_players')).rows[0].c, 2);
assert.equal((await db.query('select count(*)::int c from matchmaking_queue where room_id is null')).rows[0].c, 1, 'yalnız üçüncü bekliyor');
const r4 = await join(4); assert.equal(r4.status, 'matched', 'dördüncü üçüncüyle eşleşir');
assert.equal((await db.query('select count(*)::int c from rooms')).rows[0].c, 2);
assert.equal((await db.query('select count(distinct player_id)::int c from room_players')).rows[0].c, 4, 'kimse iki odada değil');
assert.equal((await join(1)).room_id, r2.room_id === undefined ? undefined : (await join(1)).room_id, 'tekrar çağrı aynı snapshot');
console.log('esleme dogrulugu: iki kisi tam bir kez eslesti, ucuncu bekledi');

// (c) Geri alma.
{
  const geri = read('geri_al/2026-11-05_olcek_tur5_geri.sql');
  await db.exec(geri);
  assert.equal(await defOnce('join_matchmaking(text)'), joinEski, 'geri alma join birebir');
  assert.equal(await defOnce('get_my_league()'), ligEski, 'geri alma lig birebir');
  assert.equal((await db.query("select count(*)::int c from olcek_tur3_yedek where ad like 'tur5:%'")).rows[0].c, 0);
  await uygula(); // yeniden ileri
  // (c2) Geri alma ya hep ya hiç: tek yedek eksikse hiçbir şey dönmez.
  {
    const yamali = await defOnce('join_matchmaking(text)');
    const lyamali = await defOnce('get_my_league()');
    const yedekler = (await db.query('select * from olcek_tur3_yedek')).rows;
    await db.exec("delete from olcek_tur3_yedek where ad = 'tur5:public.get_my_league()'");
    await assert.rejects(db.exec(geri), /yedek satırı yok/);
    await db.exec('rollback');
    assert.equal(await defOnce('join_matchmaking(text)'), yamali, 'eksik yedekte join dönmedi');
    await db.exec("delete from olcek_tur3_yedek where ad = 'tur5:public.get_my_league()'");
    for (const y of yedekler) await db.query('insert into olcek_tur3_yedek values ($1,$2,$3) on conflict do nothing', [y.ad, y.tanim, y.alindi]);
    await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:', '-- md5:0') where ad like 'tur5:%'");
    await assert.rejects(db.exec(geri), /bozuk/);
    await db.exec('rollback');
    await db.exec("update olcek_tur3_yedek set tanim = replace(tanim, '-- md5:0', '-- md5:')");
    // Uygulanmış sayılan dalda yedek yoksa göç durur.
    await db.exec('delete from olcek_tur3_yedek');
    await assert.rejects(db.exec(tur5), /ne bilinen canlı taban ne de sağlam yamalı/);
    await db.exec('rollback');
    for (const y of yedekler) await db.query('insert into olcek_tur3_yedek values ($1,$2,$3)', [y.ad, y.tanim, y.alindi]);
    // İşlev yoksa yeniden yaratma yok.
    await db.exec('drop function public.get_my_league()');
    await assert.rejects(db.exec(geri), /yok; geri alma durdu/);
    await db.exec('rollback');
    await db.exec(lyamali);
    await db.exec(tur5); // sağlam yamalı durumda sorunsuz (yeniden ileri)
    console.log('geri alma hep-ya-hic, bozuk zincir, eksik islev, yedeksiz uygulanmis dali dogru');
  }
  // (d) göçten sonra gövde değişirse geri alma durur.
  await db.exec("create or replace function public.get_my_league() returns jsonb language sql as $$ select '{}'::jsonb $$");
  await assert.rejects(db.exec(geri), /canlı gövdesi göçten sonra değişmiş/);
  await db.exec('rollback');
  console.log('geri alma eski govdeleri birebir dondurdu, degismis govdede durur');
}
// (e) Beklenmeyen taban: göç durur.
await db.exec("create or replace function public.get_my_league() returns jsonb language sql as $$ select '{}'::jsonb $$");
await db.exec("delete from olcek_tur3_yedek");
await assert.rejects(db.exec(tur5), /ne bilinen canlı taban ne de sağlam yamalı/);
await db.exec('rollback');
console.log('TAMAM');
