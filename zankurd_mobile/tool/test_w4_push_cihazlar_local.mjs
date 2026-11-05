// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_w4_push_cihazlar_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-16_w4_push_cihazlar.sql için (GPT-6 Pro ALAN 4 #23 #13 #21):
//  - üç canlı taban gövdesi zincirden kurulur, md5'leri göçteki sabitlerle karşılaştırılır;
//    bozuk taban reddedilir; yedek + md5 zinciri; yeniden uygulama reddedilir;
//  - #23 KUSUR (eski şema): aynı hesabın ikinci cihazı birincinin jetonunu ezer, tek jeton
//    kalır. Göçten sonra ESKİ istemci yolu (set_fcm_token) iki cihazı da cihaz tablosuna
//    yazar; çıkış yalnız o cihazı siler; eski parametresiz çıkış güvenli tarafta hepsini siler;
//    jeton başka hesaba geçince satır taşınır; cihaz sınırı 10;
//  - #13 KUSUR: jetonu olmayan kullanıcının işi Edge'i uyandırıyordu; artık uyandırmaz;
//  - #21: kilitsiz sönümleme gövdede (FOR UPDATE SKIP LOCKED);
//  - geri alma eski gövdeleri birebir döndürür.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const md5 = t => crypto.createHash('md5').update(t).digest('hex');
const cut = (src, startRe, endMarker) => {
  const m = startRe.exec(src);
  assert(m, 'bulunamadı: ' + startRe);
  const end = src.indexOf(endMarker, m.index);
  return src.slice(m.index, end + endMarker.length);
};
const sosyal = read('2026-10-15_sosyal_ve_sertlestirme.sql');
const setFcm = cut(sosyal, /create or replace function public\.set_fcm_token\(p_token text\)/, '$function$;');
const clear0 = cut(sosyal, /create or replace function public\.clear_my_fcm_token\(\)/, '$function$;');
const tur8 = read('2026-11-06_push_tur8.sql');
const clear1 = cut(tur8, /create function public\.clear_my_fcm_token\(p_token text\)/, '$function$;');
const clearFcmUid = cut(read('2026-10-13_push_delivery.sql'), /create or replace function public\.clear_fcm_token\(p_user_id uuid, p_token text\)/, '$$;');
const wake10 = cut(read('2026-10-31_push_delivery_v2.sql'), /create function public\.wake_push_delivery_v2\(\)/, '$wake$;');
const wake11 = cut(read('2026-11-04_olcek_sertlestirme.sql'), /create or replace function public\.wake_push_delivery_v2\(\)/, '$wake$;');

const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');

async function yeniDb({wakeTaban = true} = {}) {
  const db = await PGlite.create();
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable
      as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
    set check_function_bodies = off;
    create table olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
    revoke all on olcek_tur3_yedek from public, anon, authenticated;
    create table profiles(id uuid primary key references auth.users(id), fcm_token text);
    create table push_outbox(id uuid primary key default gen_random_uuid(), to_user_id uuid,
      delivery_status text default 'pending', claimed_at timestamptz, claim_token uuid,
      next_attempt_at timestamptz default now() - interval '1 second', lease_until timestamptz);
    create table push_delivery_v2_config(singleton boolean primary key default true, enabled boolean not null default true);
    insert into push_delivery_v2_config(singleton) values (true);
    alter table push_delivery_v2_config add column if not exists last_wake_at timestamptz;
    create schema vault; create table vault.decrypted_secrets(name text, decrypted_secret text);
    insert into vault.decrypted_secrets values ('send_push_url','synthetic'),('cron_secret','synthetic');
    create schema net; create sequence net.calls;
    create function net.http_post(url text, headers jsonb default '{}', body jsonb default '{}', timeout_milliseconds integer default 1000)
      returns bigint language sql as $$ select nextval('net.calls') $$;
    ${setFcm}
    ${clear0}
    ${clear1}
    ${clearFcmUid}
    ${wake10}
    ${wake11}
    revoke all on function public.set_fcm_token(text) from public, anon;
    grant execute on function public.set_fcm_token(text) to authenticated;
    revoke all on function public.clear_my_fcm_token() from public, anon;
    grant execute on function public.clear_my_fcm_token() to authenticated, service_role;
    revoke all on function public.clear_my_fcm_token(text) from public, anon;
    grant execute on function public.clear_my_fcm_token(text) to authenticated, service_role;
    revoke all on function public.clear_fcm_token(uuid, text) from public, anon, authenticated;
    grant execute on function public.clear_fcm_token(uuid, text) to service_role;
    revoke all on function public.wake_push_delivery_v2() from public, anon, authenticated, service_role;
  `);
  return db;
}
const IMZA = ['public.clear_my_fcm_token()', 'public.clear_my_fcm_token(text)', 'public.wake_push_delivery_v2()'];
const defOf = async (db, imza) => (await db.query(`select pg_get_functiondef('${imza}'::regprocedure) d`)).rows[0].d;
const one = async (db, s) => (await db.query(s)).rows[0];
const wakes = async db => (await one(db, `select coalesce((select last_value from net.calls where is_called), 0)::int n`)).n;

// 1. Taban md5'leri zincirden; göçteki sabitlerle aynı. İlk çalıştırmada sabitler yer tutucudur:
//    değerler ekrana yazılır, göçe işlenir.
let db = await yeniDb();
const taban = [];
for (const i of IMZA) taban.push(md5(await defOf(db, i)));
let goc = read('2026-11-16_w4_push_cihazlar.sql');
const tabanSabit = [...goc.matchAll(/\('public\.[a-z_0-9()]+', '([0-9a-f_A-Z]{32}|__TABAN_\d__)', '([0-9a-f]{32}|__NIHAI_\d__)'\)/g)];
assert.equal(tabanSabit.length, 3, 'göçte üç (imza, taban, nihai) satırı bekleniyor');
let nihai = [];
{
  // Nihai md5'i bul: sabitleri tabanla doldur, nihai kontrolünü gizle, uygula, oku.
  const d0 = await yeniDb();
  let g0 = goc;
  IMZA.forEach((_, k) => {
    g0 = g0.replace(tabanSabit[k][1], taban[k]);
    g0 = g0.replace(tabanSabit[k][2], 'f'.repeat(32));
  });
  g0 = g0.replace("if md5(pg_get_functiondef(to_regprocedure(d.imza))) <> d.nihai then",
    "if false then");
  await d0.exec(g0);
  for (const i of IMZA) nihai.push(md5(await defOf(d0, i)));
}
IMZA.forEach((_, k) => {
  if (tabanSabit[k][1] !== taban[k] || tabanSabit[k][2] !== nihai[k]) {
    console.log('GÖÇE İŞLENECEK:', JSON.stringify({imza: IMZA[k], taban: taban[k], nihai: nihai[k]}));
  }
});
IMZA.forEach((_, k) => {
  assert.equal(tabanSabit[k][1], taban[k], 'taban md5 göçle uyuşmuyor: ' + IMZA[k]);
  assert.equal(tabanSabit[k][2], nihai[k], 'nihai md5 göçle uyuşmuyor: ' + IMZA[k]);
});

// 2. Bozuk taban reddedilir, hiçbir şey değişmez.
{
  const bozuk = await yeniDb();
  await bozuk.exec(`create or replace function public.clear_my_fcm_token() returns void language plpgsql security definer set search_path to 'public' as $f$ begin return; end; $f$;`);
  await assert.rejects(() => bozuk.exec(goc), /bilinen canlı taban değil/);
  await bozuk.exec('rollback');
  assert.equal((await one(bozuk, 'select count(*)::int c from olcek_tur3_yedek')).c, 0);
  assert.equal((await one(bozuk, `select to_regclass('public.push_devices') is null x`)).x, true);
}

// 3. ESKİ şemada kusur #23: ikinci cihaz birincinin jetonunu ezer.
await db.exec(`insert into auth.users values ('${U(1)}'),('${U(2)}'),('${U(3)}')`);
await db.exec(`insert into profiles(id) values ('${U(1)}'),('${U(2)}'),('${U(3)}')`);
const as = async (n, sql) => { await db.exec(`select set_config('test.uid','${U(n)}',false)`); return db.exec(sql); };
await as(1, `select public.set_fcm_token('T-A')`);
await as(1, `select public.set_fcm_token('T-B')`);
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, 'T-B',
  'KUSUR gösterilemedi: eski şemada yalnız son cihazın jetonu kalmalıydı');
// Önceden kayıtlı bir jeton göçte cihaz tablosuna taşınmalı.
await as(2, `select public.set_fcm_token('T-LEGACY')`);

// 4. Göç.
await db.exec(goc);
assert.equal((await one(db, `select count(*)::int c from push_devices where token='T-LEGACY' and user_id='${U(2)}'`)).c, 1,
  'mevcut profil jetonu göçle cihaz tablosuna taşınmalı');
for (let k = 0; k < 3; k++) {
  assert.equal(md5(await defOf(db, IMZA[k])), nihai[k]);
  const y = (await one(db, `select tanim from olcek_tur3_yedek where ad='w4:${IMZA[k]}'`)).tanim;
  assert(y.includes('-- md5:' + taban[k]) && y.endsWith('-- yama-md5:' + nihai[k]), 'yedek zinciri ' + IMZA[k]);
}
await assert.rejects(() => db.exec(goc), /zaten uygulanmış/);
await db.exec('rollback');

// 5. ESKİ istemci yolu (set_fcm_token) iki cihazı da cihaz tablosuna yazar (#23).
await as(1, `select public.set_fcm_token('T-A')`);
await as(1, `select public.set_fcm_token('T-B')`);
const tokens = async u => (await db.query(`select token from public.get_push_device_tokens('${U(u)}')`)).rows.map(r => r.token);
assert.deepEqual((await tokens(1)).sort(), ['T-A', 'T-B'], 'iki cihaz da kayıtlı');
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, 'T-B', 'profil jetonu son cihaz (claim uyumu)');
assert.equal((await tokens(1))[0], 'T-B', 'en yeni önce');

// 6. Jeton başka hesaba geçince satır taşınır; eski hesabın öteki cihazı korunur.
await as(3, `select public.set_fcm_token('T-A')`);
assert.deepEqual(await tokens(3), ['T-A']);
assert.deepEqual(await tokens(1), ['T-B'], 'U1 artık yalnız T-B; T-A başka hesaba geçti');

// 7. Yeni istemci çıkışı: yalnız o cihaz; profil jetonu başka cihaza yönlenir.
await as(1, `select public.set_fcm_token('T-C')`);
assert.deepEqual((await tokens(1)).sort(), ['T-B', 'T-C']);
await as(1, `select public.clear_my_fcm_token('T-B')`);
assert.deepEqual(await tokens(1), ['T-C'], 'T-B (profil jetonu olmayan cihaz) çıkışı T-C\'yi silmez');
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, 'T-C');
await as(1, `select public.set_fcm_token('T-D')`);
await as(1, `select public.clear_my_fcm_token('T-D')`);
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, 'T-C',
  'profil jetonu çıkan cihazınsa kalan cihaza yönlendirilir (claim jetonsuz kalmaz)');
await as(1, `select public.clear_my_fcm_token('T-C')`);
assert.deepEqual(await tokens(1), []);
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, null);

// 8. ESKİ istemcinin parametresiz çıkışı güvenli tarafta: hepsini siler.
await as(1, `select public.set_fcm_token('T-E')`);
await as(1, `select public.set_fcm_token('T-F')`);
await as(1, `select public.clear_my_fcm_token()`);
assert.deepEqual(await tokens(1), []);
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, null);
// Başka kullanıcının satırlarına dokunmaz.
assert.deepEqual(await tokens(3), ['T-A']);

// 9. Edge: UNREGISTERED jeton temizliği (service_role işlevi).
await as(1, `select public.set_fcm_token('T-G')`);
await as(1, `select public.set_fcm_token('T-H')`);
await db.exec(`select public.clear_push_device('${U(1)}', 'T-H')`);
assert.deepEqual(await tokens(1), ['T-G']);
assert.equal((await one(db, `select fcm_token t from profiles where id='${U(1)}'`)).t, 'T-G');
await db.exec(`select public.clear_push_device('${U(2)}', 'T-G')`); // yanlış sahip: dokunmaz
assert.deepEqual(await tokens(1), ['T-G']);

// 10. Cihaz sınırı: kullanıcı başına en çok 10 (en eski silinir).
for (let i = 0; i < 13; i++) await as(1, `select public.set_fcm_token('T-N${i}')`);
assert.equal((await one(db, `select count(*)::int c from push_devices where user_id='${U(1)}'`)).c, 10);
assert((await tokens(1)).includes('T-N12') && !(await tokens(1)).includes('T-N0'), 'en yeni kalır, en eski gider');

// 11. İşlevler/tablo istemciye kapalı.
for (const f of ['public.get_push_device_tokens(uuid)', 'public.clear_push_device(uuid,text)']) {
  for (const rol of ['anon', 'authenticated', 'public']) {
    assert.equal((await one(db, `select has_function_privilege('${rol}', '${f}', 'execute') x`)).x, false, f + ' ' + rol);
  }
  assert.equal((await one(db, `select has_function_privilege('service_role', '${f}', 'execute') x`)).x, true, f);
}
for (const rol of ['anon', 'authenticated']) {
  assert.equal((await one(db, `select has_table_privilege('${rol}', 'public.push_devices', 'select,insert,update,delete') x`)).x, false, rol);
}

// 12. #13: jetonsuz kullanıcının işi Edge'i uyandırmaz; jetonlu kullanıcınınki uyandırır.
await db.exec(`delete from push_outbox; update push_delivery_v2_config set last_wake_at = null`);
await as(2, `select public.clear_my_fcm_token()`); // U2: jetonsuz
await db.exec(`insert into push_outbox(to_user_id) values ('${U(2)}')`);
const w0 = await wakes(db);
assert.equal((await one(db, `select public.wake_push_delivery_v2() r`)).r, false, 'jetonsuz iş uyandırmamalı');
assert.equal(await wakes(db), w0);
await db.exec(`delete from push_outbox; insert into push_outbox(to_user_id) values ('${U(1)}')`); // U1: jetonlu
assert.equal((await one(db, `select public.wake_push_delivery_v2() r`)).r, true, 'jetonlu iş uyandırmalı');
assert.equal(await wakes(db), w0 + 1);
// Sönümleme (2 sn) korunur.
assert.equal((await one(db, `select public.wake_push_delivery_v2() r`)).r, false, '2 sn içinde ikinci uyandırma yok');
// Yalnız cihaz satırı olan (profil jetonu boş) kullanıcının işi de uyandırır.
await db.exec(`update push_delivery_v2_config set last_wake_at = null; update profiles set fcm_token = null where id='${U(1)}'`);
// (profil jetonu null yapınca tetikleyici cihaz satırını sildi; elle geri koy.)
await db.exec(`insert into push_devices(token, user_id) values ('T-ONLY', '${U(1)}') on conflict do nothing`);
assert.equal((await one(db, `select public.wake_push_delivery_v2() r`)).r, true, 'cihaz satırı olan kullanıcı uyandırır');

// 13. #21: kilitsiz sönümleme gövdede.
{
  const g = await defOf(db, 'public.wake_push_delivery_v2()');
  assert(g.includes('for update skip locked'), 'config satırı SKIP LOCKED ile alınmalı');
  assert(g.indexOf('skip locked') < g.indexOf('update public.push_delivery_v2_config'), 'kilit UPDATE\'ten önce');
}

// 14. Geri alma eski gövdeleri birebir döndürür; ikinci kez de temiz.
await db.exec(read('geri_al/2026-11-16_w4_push_cihazlar_geri.sql'));
for (let k = 0; k < 3; k++) assert.equal(md5(await defOf(db, IMZA[k])), taban[k], 'geri alma ' + IMZA[k]);
assert.equal((await one(db, `select count(*)::int c from olcek_tur3_yedek where ad like 'w4:%'`)).c, 0);
assert.equal((await one(db, `select to_regclass('public.push_devices') is null x`)).x, true);
assert.equal((await one(db, `select count(*)::int c from pg_trigger where tgname='trg_profiles_fcm_devices_sync'`)).c, 0);
console.log('W4 PUSH CIHAZLAR LOCAL: TAMAM');
