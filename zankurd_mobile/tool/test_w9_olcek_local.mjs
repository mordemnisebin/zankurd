// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_w9_olcek_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-18_w9_olcek.sql için (ChatGPT Pro alan 9 #15, #16, #17):
//  - ESKİ KUSUR göç öncesi gösterilir: terk edilmiş kullanıcının 3 günden eski
//    bileti kendi hazırlama çağrısı olmadan SİLİNMEZ; temizlik işleri günde bir;
//  - göçten sonra genel süpürme eski biletleri siler, yenisine/kullanılmışa
//    dokunmaz (yalnız yaşa bakar), kalan sınırı toplu (parti) işler;
//  - 3 cron zamanlaması 4/4/3 saatlik olur, KOMUT metni değişmez, eski değer
//    yedek tabloya yazılır; yeniden uygulama idempotent;
//  - mevcut işlev gövdeleri (md5) DEĞİŞMEZ; süpürme işlevi istemci rollerine kapalı;
//  - beklenmeyen eski zamanlama / eksik iş göçü durdurur;
//  - geri alma zamanlamaları eski değerine döndürür ve yeni nesneleri kaldırır.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const val = async (sql, args = []) => Object.values((await db.query(sql, args)).rows[0])[0];
let n = 0;
const ok = m => console.log('PASS', ++n, m);
const reddet = async (sql, parca, m) => {
  await assert.rejects(() => db.exec(sql), e => String(e.message).includes(parca), m);
  await db.exec('rollback').catch(() => {});
  ok(m);
};

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  grant usage on schema public to authenticated, anon;
  create table verified_solo_selections(
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    question_ids uuid[] not null,
    created_at timestamptz not null default clock_timestamp(),
    used_by_round uuid);
  create table olcek_tur3_yedek(ad text primary key, tanim text not null, alindi timestamptz not null default now());
  create function push_outbox_retention(p_days integer default 14, p_batch integer default 5000)
    returns bigint language sql as $$ select 0::bigint $$;
  create function rate_limit_events_sweep(p_batch integer default 5000)
    returns bigint language sql as $$ select 0::bigint $$;
  -- pg_cron taklidi: iş tablosu + schedule/alter_job/unschedule.
  create schema cron;
  create table cron.job(jobid bigint generated always as identity primary key,
    jobname text unique, schedule text, command text);
  create function cron.schedule(text, text, text) returns bigint language sql
    as $$ insert into cron.job(jobname, schedule, command) values($1,$2,$3) returning jobid $$;
  create function cron.alter_job(job_id bigint, schedule text default null, command text default null,
    database text default null, username text default null, active boolean default null)
    returns void language sql
    as $$ update cron.job j set schedule = coalesce($2, j.schedule), command = coalesce($3, j.command) where j.jobid = $1 $$;
  create function cron.unschedule(text) returns boolean language sql
    as $$ with d as (delete from cron.job where jobname = $1 returning 1) select exists(select 1 from d) $$;
`);
// pg_cron eklentisi PGlite'ta yok: göçün create extension satırı yerel uyarlamada atlanır.
const gocSql = read('2026-11-18_w9_olcek.sql').replace(
  'create extension if not exists pg_cron with schema pg_catalog;', '-- (yerelde pg_cron taklidi kurulu)');

const U = i => '20000000-0000-0000-0000-' + String(i).padStart(12, '0');
for (let i = 1; i <= 3; i++) await db.query('insert into auth.users values ($1)', [U(i)]);
const IDEM = `delete from idempotent_ops o where (o.user_id, o.op_key) in (select 1 limit 20000)`;
await db.exec(`
  insert into cron.job(jobname, schedule, command) values
   ('push-outbox-retention', '20 0 * * *', 'select public.push_outbox_retention(14, 5000)'),
   ('rate-limit-events-sweep', '25 0 * * *', 'select public.rate_limit_events_sweep(5000)'),
   ('idempotent-ops-temizlik', '47 3 * * *', $c$${IDEM}$c$)`);
const bilet = (u, yas, kullanildi = false) => db.query(
  `insert into verified_solo_selections(user_id, question_ids, created_at, used_by_round)
   values ($1, array[gen_random_uuid()], clock_timestamp() - $2::interval, $3)`,
  [U(u), yas, kullanildi ? U(9) : null]);
// u1: terk edilmiş (hiç dönmeyecek) eski biletler; u2: yeni; u3: eski ama kullanılmış.
for (let i = 0; i < 7; i++) await bilet(1, '10 days');
await bilet(2, '1 hour');
await bilet(3, '4 days', true);
const sayim = () => val('select count(*)::int from verified_solo_selections');
const md5 = sig => val(`select md5(pg_get_functiondef('${sig}'::regprocedure))`);
const md5Once = [await md5('public.push_outbox_retention(integer,integer)'),
                 await md5('public.rate_limit_events_sweep(integer)')];

// --- Göç öncesi: ESKİ KUSUR ----------------------------------------------------------
assert.equal(await sayim(), 9);
assert.equal(await val(`select to_regprocedure('public.verified_solo_selections_sweep(integer)') is null`), true);
ok('ESKİ KUSUR: terk edilmiş kullanıcının eski biletleri için genel süpürme yok (9 satır kalıcı)');
assert.equal(await val(`select schedule from cron.job where jobname='push-outbox-retention'`), '20 0 * * *');
ok('ESKİ KUSUR: temizlik işleri günde bir koşu (günlük tavan 200.000 / 20.000 satır)');

// --- Ön koşul ihlalleri göçü durdurur -------------------------------------------------
await db.exec(`update cron.job set schedule = '0 1 * * *' where jobname = 'rate-limit-events-sweep'`);
await reddet(gocSql, 'beklenen eski değer değil', 'beklenmeyen eski zamanlama göçü durdurur');
assert.equal(await val(`select to_regprocedure('public.verified_solo_selections_sweep(integer)') is null`), true);
ok('durdurulan göçte yeni işlev bırakılmadı (ya hep ya hiç)');
await db.exec(`update cron.job set schedule = '25 0 * * *' where jobname = 'rate-limit-events-sweep'`);
await db.exec(`delete from cron.job where jobname = 'idempotent-ops-temizlik'`);
await reddet(gocSql, 'cron işi yok', 'eksik cron işi göçü durdurur');
await db.exec(`insert into cron.job(jobname, schedule, command) values ('idempotent-ops-temizlik','47 3 * * *', $c$${IDEM}$c$)`);

// --- Göç -----------------------------------------------------------------------------
await db.exec(gocSql);
ok('göç uygulandı');
const zam = async ad => val(`select schedule from cron.job where jobname=$1`, [ad]);
assert.equal(await zam('push-outbox-retention'), '20 */4 * * *');
assert.equal(await zam('rate-limit-events-sweep'), '25 */4 * * *');
assert.equal(await zam('idempotent-ops-temizlik'), '47 */3 * * *');
ok('üç temizlik işi 4/4/3 saatlik');
assert.equal(await val(`select command from cron.job where jobname='push-outbox-retention'`),
  'select public.push_outbox_retention(14, 5000)');
assert.equal(await val(`select command from cron.job where jobname='idempotent-ops-temizlik'`), IDEM);
ok('cron komut metinleri DEĞİŞMEDİ');
assert.equal(await val(`select tanim from olcek_tur3_yedek where ad='w9:cron:push-outbox-retention'`),
  '20 0 * * *\nselect public.push_outbox_retention(14, 5000)');
assert.equal(await val(`select count(*)::int from olcek_tur3_yedek where ad like 'w9:cron:%'`), 3);
ok('eski zamanlamalar yedek tabloya yazıldı');
assert.equal(await md5('public.push_outbox_retention(integer,integer)'), md5Once[0]);
assert.equal(await md5('public.rate_limit_events_sweep(integer)'), md5Once[1]);
ok('mevcut işlev gövdeleri (md5) değişmedi');
assert.equal(await zam('verified-solo-selections-sweep'), '35 */6 * * *');
ok('yeni süpürme işi 6 saatte bir kuruldu');

// --- Davranış: genel süpürme ----------------------------------------------------------
{
  // Yeni bilet ve KULLANILMIŞ ama taze bilet korunur; eskiler (kullanılmış olsa da) silinir.
  await bilet(2, '2 days 23 hours', true);
  const silinen = await val(`select public.verified_solo_selections_sweep(100)`);
  assert.equal(Number(silinen), 8, '7 terk edilmiş + 1 kullanılmış eski bilet');
  assert.equal(await sayim(), 2, 'taze iki bilet kalır');
  ok('genel süpürme yalnız 3 günden eski biletleri siler (terk edilmiş kullanıcı dahil)');
  assert.equal(Number(await val(`select public.verified_solo_selections_sweep(100)`)), 0);
  ok('süpürme idempotent');
}
{
  // Parti sınırı: 250 eski bilet, parti 100 -> döngü hepsini temizler (40 parti tavanına kadar).
  await db.exec(`insert into verified_solo_selections(user_id, question_ids, created_at)
    select '${U(1)}', array[gen_random_uuid()], clock_timestamp() - interval '9 days' from generate_series(1, 250)`);
  assert.equal(Number(await val(`select public.verified_solo_selections_sweep(100)`)), 250);
  ok('büyük birikim partiler halinde temizlenir');
}

// --- Yetkiler -------------------------------------------------------------------------
for (const rol of ['anon', 'authenticated', 'public']) {
  assert.equal(await val(`select has_function_privilege('${rol}', 'public.verified_solo_selections_sweep(integer)', 'execute')`), false);
}
ok('süpürme işlevi anon/authenticated/PUBLIC rollerine kapalı');

// --- Idempotent yeniden uygulama --------------------------------------------------------
await db.exec(gocSql);
assert.equal(await val(`select count(*)::int from cron.job where jobname='verified-solo-selections-sweep'`), 1);
assert.equal(await zam('push-outbox-retention'), '20 */4 * * *');
ok('göç ikinci kez uygulanınca idempotent (iş çoğalmaz, zamanlama aynı)');

// --- Geri alma ---------------------------------------------------------------------------
await db.exec(read('geri_al/2026-11-18_w9_olcek_geri.sql').split('-- Transaction DIŞI')[0]);
assert.equal(await zam('push-outbox-retention'), '20 0 * * *');
assert.equal(await zam('rate-limit-events-sweep'), '25 0 * * *');
assert.equal(await zam('idempotent-ops-temizlik'), '47 3 * * *');
assert.equal(await val(`select count(*)::int from cron.job where jobname='verified-solo-selections-sweep'`), 0);
assert.equal(await val(`select to_regprocedure('public.verified_solo_selections_sweep(integer)') is null`), true);
assert.equal(await val(`select count(*)::int from olcek_tur3_yedek where ad like 'w9:cron:%'`), 0);
ok('geri alma: zamanlamalar eski değerine döndü, yeni iş/işlev kalktı');

console.log(`TAMAM: ${n} kontrol`);
