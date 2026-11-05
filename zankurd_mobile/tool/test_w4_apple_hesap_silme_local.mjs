// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_w4_apple_hesap_silme_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-16_w4_apple_hesap_silme.sql için (GPT-6 Pro ALAN 4 #3 #7 #9):
//  - canlı taban zincirden kurulur (kalabalık oda + kilit yaması + tur10 yaması) ve md5'i
//    göçteki sabit (2e5e96d2…) ile karşılaştırılır; bozuk taban reddedilir;
//  - #3 KUSUR: eski şemada hesap silinince apple_auth_tokens satırı CASCADE ile yok olur
//    (başarısız iptalin jetonu kaybolur). Göçten sonra satır kalır, yalnız yetim listesinde
//    görünür; YAŞAYAN kullanıcının jetonu listede asla yer almaz; istemciler çağıramaz;
//  - #9 KUSUR: eski delete_my_account storage.objects satırlarını siliyordu (fiziksel dosya
//    kalır, süpürücü göremez); göçten sonra satırlar kalır;
//  - #7 imleç tablosu tek satır, istemciye kapalı; geri alma eski gövdeyi birebir döndürür.
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
const kalabalik = read('2026-10-16_kalabalik_oda.sql');
const m = /CREATE OR REPLACE FUNCTION public\.delete_my_account\(\)/.exec(kalabalik);
const end = kalabalik.indexOf('$function$;', kalabalik.indexOf('$function$', m.index) + 1);
let taban10 = kalabalik.slice(m.index, end + '$function$;'.length);
taban10 = taban10.replace(
  "perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));",
  "perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_user_id::text, 0));");
const tur10 = read('2026-11-08_hesap_silme_yasal.sql');

const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');

async function yeniDb({tur10Uygula = true} = {}) {
  const db = await PGlite.create();
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable
      as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
    create schema storage;
    create table storage.objects(bucket_id text, name text);
    create function storage.foldername(n text) returns text[] language sql as $$ select string_to_array(n, '/') $$;
    set check_function_bodies = off;
    create table olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
    revoke all on olcek_tur3_yedek from public, anon, authenticated;
    create table profiles(id uuid primary key);
    create table rooms(id uuid primary key);
    create table room_players(room_id uuid, player_id uuid);
    create table room_result_snapshots(room_id uuid, player_id uuid, payload jsonb not null,
      primary key (room_id, player_id));
    ${taban10}
    revoke all on function public.delete_my_account() from public;
    grant execute on function public.delete_my_account() to authenticated;
  `);
  if (tur10Uygula) await db.exec(tur10);
  await db.exec(read('2026-10-02_apple_auth_tokens.sql'));
  return db;
}
const defOnce = async db => (await db.query(`select pg_get_functiondef('public.delete_my_account()'::regprocedure) d`)).rows[0].d;

// 1. Taban md5'i göçteki sabitle aynı (zincirden yeniden kuruldu).
let db = await yeniDb();
const tabanMd5 = md5(await defOnce(db));
let goc = read('2026-11-16_w4_apple_hesap_silme.sql');
assert.equal(tabanMd5, '2e5e96d2061716e7a0f876ee03b2d7be', 'zincirden kurulan taban md5 beklenen canlı değer değil');
assert(goc.includes(`'${tabanMd5}'`), 'göçteki taban md5 yerel zincirle uyuşmuyor: ' + tabanMd5);

// Nihai md5'i bul: yer tutucuyu kendi kendine eşitleyerek bir kez uygula.
{
  const d0 = await yeniDb();
  await d0.exec(goc.replace("<> '109b68e209e89f73d6cc3e5cdf5d6ba0'", "<> md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()')))"));
  globalThis.nihai = md5(await defOnce(d0));
}
const nihaiMd5 = globalThis.nihai;
assert(goc.includes(`<> '${nihaiMd5}'`), 'göçteki nihai md5 sabiti güncel değil: ' + nihaiMd5);

// 2. Bozuk taban reddedilir, hiçbir şey değişmez.
{
  const bozuk = await yeniDb({tur10Uygula: false});
  await assert.rejects(() => bozuk.exec(goc), /bilinen canlı taban değil/);
  await bozuk.exec('rollback');
  assert.equal((await bozuk.query('select count(*)::int c from olcek_tur3_yedek')).rows[0].c, 0);
}

// 3. ESKİ şemada kusur: hesap silinince jeton CASCADE ile yok olur (#3) ve doğrudan SQL
//    silme storage.objects satırlarını götürür (#9).
await db.exec(`insert into auth.users values ('${U(1)}'),('${U(2)}'),('${U(3)}')`);
await db.exec(`insert into profiles values ('${U(1)}'),('${U(2)}'),('${U(3)}')`);
await db.exec(`insert into apple_auth_tokens(user_id, refresh_token) values ('${U(1)}','rt-1'),('${U(2)}','rt-2'),('${U(3)}','rt-3')`);
// delete_my_account'un kendisi onlarca tabloya dokunur (yerel kurulumda yok); davranış
// gövde metniyle ve auth.users silmesinin FK etkisiyle sınanır.
assert((await defOnce(db)).includes('delete from storage.objects'),
  'KUSUR gösterilemedi: eski gövde doğrudan storage.objects siliyor olmalıydı');
const eskiSatir = async () => (await db.query(`select count(*)::int c from apple_auth_tokens where user_id='${U(1)}'`)).rows[0].c;
await db.exec(`delete from auth.users where id='${U(1)}'`);
assert.equal(await eskiSatir(), 0, 'KUSUR gösterilemedi: eski şemada CASCADE jetonu silmeliydi');
// Kullanıcı 1'i yeniden kur: göçten sonrası için.
await db.exec(`insert into auth.users values ('${U(1)}')`);

// 4. Göç uygulanır; nihai md5, yedek zinciri, yeniden çalıştırma reddi.
await db.exec(goc);
assert.equal(md5(await defOnce(db)), nihaiMd5);
const yedek = (await db.query(`select tanim from olcek_tur3_yedek where ad='w4:public.delete_my_account()'`)).rows[0].tanim;
assert(yedek.includes('-- md5:' + tabanMd5) && yedek.endsWith('-- yama-md5:' + nihaiMd5));
await assert.rejects(() => db.exec(goc), /zaten uygulanmış/);
await db.exec('rollback');

// 5. #3: FK yok; hesap silinince jeton KALIR ve yalnız yetim olarak listelenir.
await db.exec(`insert into apple_auth_tokens(user_id, refresh_token) values ('${U(1)}','rt-1')`);
await db.exec(`delete from auth.users where id='${U(1)}'`);
assert.equal(await eskiSatir(), 1, 'hesap silinince başarısız iptalin jetonu kaybolmamalı');
const yetim = async () => (await db.query(`select user_id::text u, refresh_token t from public.apple_orphan_tokens(50) order by 1`)).rows;
let y = await yetim();
assert.deepEqual(y.map(r => r.u), [U(1)], 'yalnız silinmiş kullanıcının jetonu yetimdir; yaşayanlarınki (2, 3) ASLA');
// Yaşayan kullanıcının jetonu hiçbir koşulda dönmez, başarısızlık sayacı da ona işlemez.
await db.exec(`select public.apple_orphan_failed('${U(2)}')`);
assert.equal((await db.query(`select attempts from apple_auth_tokens where user_id='${U(2)}'`)).rows[0].attempts, 0);
// Başarısız deneme sayılır ve 10 dk bekletir; sonra yeniden görünür; 20 denemede vazgeçilir.
await db.exec(`select public.apple_orphan_failed('${U(1)}')`);
assert.deepEqual(await yetim(), [], 'yeni başarısız deneme 10 dk beklemeli');
await db.exec(`update apple_auth_tokens set last_attempt_at = now() - interval '11 minutes' where user_id='${U(1)}'`);
assert.equal((await yetim()).length, 1);
await db.exec(`update apple_auth_tokens set attempts = 20 where user_id='${U(1)}'`);
assert.deepEqual(await yetim(), [], '20 denemeden sonra vazgeçilir');
// Başarıda satır silinir (Edge: delete .eq(user_id)).
await db.exec(`delete from apple_auth_tokens where user_id='${U(1)}'`);

// 6. İşlevler yalnız service_role; tablo istemciye kapalı; imleç tek satır.
for (const f of ['public.apple_orphan_tokens(integer)', 'public.apple_orphan_failed(uuid)']) {
  for (const rol of ['anon', 'authenticated', 'public']) {
    assert.equal((await db.query(`select has_function_privilege('${rol}', '${f}', 'execute') x`)).rows[0].x, false, f + ' ' + rol);
  }
  assert.equal((await db.query(`select has_function_privilege('service_role', '${f}', 'execute') x`)).rows[0].x, true, f);
}
for (const t of ['avatar_sweep_state', 'apple_auth_tokens']) {
  for (const rol of ['anon', 'authenticated']) {
    assert.equal((await db.query(`select has_table_privilege('${rol}', 'public.${t}', 'select,insert,update,delete') x`)).rows[0].x, false, t + ' ' + rol);
  }
}
assert.equal((await db.query(`select count(*)::int c from avatar_sweep_state`)).rows[0].c, 1);
await assert.rejects(() => db.exec(`insert into avatar_sweep_state(id) values (2)`), /check/i);

// 7. #9: yeni gövde nesne satırlarını SİLMEZ (süpürücü görsün), hesap silme yine çalışır.
{
  const g = await defOnce(db);
  assert(!g.includes('storage.objects'), 'yeni gövde doğrudan storage.objects silmemeli');
  assert(g.includes('delete from public.player_answers') && g.includes('anonymize_deleted_user_in_snapshots'),
    'gövdenin geri kalanı korunmuş');
}

// 8. Geri alma eski gövdeyi birebir döndürür.
await db.exec(read('geri_al/2026-11-16_w4_apple_hesap_silme_geri.sql'));
assert.equal(md5(await defOnce(db)), tabanMd5);
assert.equal((await db.query(`select count(*)::int c from olcek_tur3_yedek where ad like 'w4:%'`)).rows[0].c, 0);
assert.equal((await db.query(`select to_regprocedure('public.apple_orphan_tokens(integer)') is null x`)).rows[0].x, true);
assert.equal((await db.query(`select to_regclass('public.avatar_sweep_state') is null x`)).rows[0].x, true);
console.log('W4 APPLE HESAP SILME LOCAL: TAMAM');
