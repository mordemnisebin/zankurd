// Yerel PostgreSQL bekçisi (PGlite). node tool/test_w7_hesap_silme_yonetim_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-18_w7_hesap_silme_yonetim.sql (GPT-6 Pro 2.1.2 alan 7 bulgu 1.3): taban = canlı W4 sonrası zincir
// (kalabalık oda + tur10 + W4), md5 109b68e2…; eski gövde yönetim kayıtlarına dokunmaz (KUSUR); göçten sonra
// günlük/ödül/moderasyon anonimleşir, başkalarınınki dokunulmaz; geri alma birebir.
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


const w4 = read('2026-11-16_w4_apple_hesap_silme.sql');
const W4_NIHAI = '109b68e209e89f73d6cc3e5cdf5d6ba0';
async function w4Db({w4Uygula = true} = {}) {
  const db = await yeniDb();
  if (w4Uygula) await db.exec(w4);
  await db.exec(`
    create table admin_audit_log (id bigint generated always as identity primary key, admin_id uuid,
      action text not null, target_type text not null, target_id text,
      detail jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
    create table admin_reward_grants (id uuid primary key default gen_random_uuid(),
      period_kind text not null, period_key text not null, user_id uuid not null,
      rank integer not null, coins integer not null default 0, badge_slug text,
      source text not null default 'manual', granted_by uuid, created_at timestamptz not null default now(),
      check ((source = 'manual') = (granted_by is not null)),
      unique (period_kind, period_key, user_id));
    create table admin_contributor_rewards (id uuid primary key default gen_random_uuid(),
      user_id uuid not null, coins integer not null, granted_by uuid not null,
      created_at timestamptz not null default now());
    create table user_moderation (user_id uuid primary key references auth.users(id) on delete cascade,
      state text not null, until timestamptz, note text, updated_by uuid not null,
      updated_at timestamptz not null default now());
    create table admin_settings (key text primary key, value jsonb not null, updated_by uuid,
      updated_at timestamptz not null default now());
  `);
  return db;
}
const defOnce2 = async db => (await db.query(`select pg_get_functiondef('public.delete_my_account()'::regprocedure) d`)).rows[0].d;

// 1. Taban md5 (W4 sonrası zincir) göçteki sabitle aynı.
let db = await w4Db();
const tabanMd5 = md5(await defOnce2(db));
let goc = read('2026-11-18_w7_hesap_silme_yonetim.sql');
assert.equal(tabanMd5, W4_NIHAI, 'zincirden kurulan W4 sonrası taban md5 beklenen canlı değer değil');
assert(goc.includes(`'${tabanMd5}'`), 'göçteki taban md5 yerel zincirle uyuşmuyor');

// Nihai md5: yer tutucuyu kendi kendine eşitleyerek bir kez uygula.
{
  const d0 = await w4Db();
  await d0.exec(goc.replace("<> '640c65f6fbcb60aa6ac3fea77cabec90'", "<> md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()')))"));
  globalThis.nihai = md5(await defOnce2(d0));
}
const nihaiMd5 = globalThis.nihai;
assert(goc.includes(`<> '${nihaiMd5}'`), 'göçteki nihai md5 sabiti güncel değil: ' + nihaiMd5);

// 2. Bozuk taban (W4 uygulanmamış) reddedilir.
{
  const bozuk = await w4Db({w4Uygula: false});
  await assert.rejects(() => bozuk.exec(goc), /bilinen canlı taban değil/);
  await bozuk.exec('rollback');
}

// 3. KUSUR: eski gövde yönetim kayıtlarına dokunmaz.
assert(!(await defOnce2(db)).includes('anonymize_deleted_user_in_admin_records'),
  'KUSUR gösterilemedi: eski gövde yönetim kaydı anonimleştirmesi içermemeliydi');

// 4. Göç uygulanır; md5 zinciri; yeniden çalıştırma reddi.
await db.exec(goc);
assert.equal(md5(await defOnce2(db)), nihaiMd5);
const yedek = (await db.query(`select tanim from olcek_tur3_yedek where ad='w7:public.delete_my_account()'`)).rows[0].tanim;
assert(yedek.includes('-- md5:' + tabanMd5) && yedek.endsWith('-- yama-md5:' + nihaiMd5));
await assert.rejects(() => db.exec(goc), /zaten uygulanmış/);
await db.exec('rollback');
const g = await defOnce2(db);
assert(g.indexOf('anonymize_deleted_user_in_snapshots') < g.indexOf('anonymize_deleted_user_in_admin_records')
  && g.indexOf('anonymize_deleted_user_in_admin_records') < g.indexOf('delete from public.player_answers'),
  'çağrı anlık görüntü anonimleştirmesinden sonra, silmelerden önce olmalı');

// 5. Davranış: yardımcı yalnız silinen kullanıcıyı anonimleştirir.
const A = U(11), B = U(12), ADMIN = U(13), ZERO = '00000000-0000-0000-0000-000000000000';
await db.exec(`insert into auth.users values ('${A}'),('${B}'),('${ADMIN}')`);
await db.exec(`
  insert into admin_audit_log(admin_id, action, target_type, target_id, detail) values
   ('${ADMIN}','user_block','user','${A}','{"days":3,"note":"küfür etti","label":"Ayşe"}'),
   ('${ADMIN}','reward_grant','user','${B}','{"coins":50,"label":"Bekir","note":"iyi"}'),
   ('${ADMIN}','x','setting','auto','{"who":"${A}"}'),
   ('${A}','question_fix','question','q1','{"x":1}');
  insert into admin_reward_grants(period_kind, period_key, user_id, rank, coins, source, granted_by) values
   ('daily','d1','${A}',1,50,'manual','${ADMIN}'), ('weekly','w1','${A}',1,50,'auto',null),
   ('daily','d1','${B}',2,30,'auto',null), ('daily','d2','${ADMIN}',3,10,'manual','${A}');
  insert into admin_contributor_rewards(user_id, coins, granted_by) values ('${A}',20,'${ADMIN}'),('${B}',20,'${A}');
  insert into user_moderation(user_id, state, note, updated_by) values ('${A}','blocked','not-a','${ADMIN}'),('${B}','warned','not-b','${A}');
  insert into admin_settings(key, value, updated_by) values ('auto_reward','true','${A}'),('k2','1','${ADMIN}');
`);
const n = (await db.query(`select public.anonymize_deleted_user_in_admin_records('${A}') n`)).rows[0].n;
assert(n > 0);
const q = async s => (await db.query(s)).rows;
const hepsi = JSON.stringify([
  await q('select * from admin_audit_log'), await q('select * from admin_reward_grants'),
  await q('select * from admin_contributor_rewards'), await q('select * from user_moderation'),
  await q('select * from admin_settings')]);
assert(!hepsi.includes(A), 'silinen kullanıcının kimliği hiçbir yönetim tablosunda kalmamalı');
assert(!hepsi.includes('Ayşe') && !hepsi.includes('küfür') && !hepsi.includes('not-a'), 'ad/not kalmamalı');
const a1 = (await q(`select * from admin_audit_log order by id`));
assert.equal(a1[0].target_id, ZERO); assert.equal(a1[0].detail.label, 'Hesabê jêbirî'); assert.equal(a1[0].detail.days, 3);
assert(!('note' in a1[0].detail));
assert.equal(a1[1].target_id, B); assert.equal(a1[1].detail.label, 'Bekir'); assert.equal(a1[1].detail.note, 'iyi', 'başkasının kaydı dokunulmaz');
assert.equal(a1[2].detail.who, ZERO); assert.equal(a1[3].admin_id, ZERO);
const gr = await q(`select * from admin_reward_grants order by period_key, period_kind`);
assert.equal(gr.length, 4, 'ödül satırları (sayılar) korunur');
assert.equal(gr.filter(r => r.user_id === B).length, 1);
assert.equal(gr.find(r => r.user_id === ADMIN).granted_by, ZERO);
assert.equal((await q(`select count(*)::int c from user_moderation where user_id='${A}'`))[0].c, 0);
assert.equal((await q(`select updated_by from user_moderation where user_id='${B}'`))[0].updated_by, ZERO);
assert.equal((await q(`select updated_by from admin_settings where key='auto_reward'`))[0].updated_by, null);
assert.equal((await q(`select updated_by from admin_settings where key='k2'`))[0].updated_by, ADMIN);

// 6. Yardımcı istemciye kapalı.
for (const rol of ['anon', 'authenticated', 'public']) {
  assert.equal((await db.query(`select has_function_privilege('${rol}', 'public.anonymize_deleted_user_in_admin_records(uuid)', 'execute') x`)).rows[0].x, false, rol);
}

// 7. Geri alma eski gövdeyi birebir döndürür.
await db.exec(read('geri_al/2026-11-18_w7_hesap_silme_yonetim_geri.sql'));
assert.equal(md5(await defOnce2(db)), tabanMd5);
assert.equal((await db.query(`select count(*)::int c from olcek_tur3_yedek where ad like 'w7:%'`)).rows[0].c, 0);
assert.equal((await db.query(`select to_regprocedure('public.anonymize_deleted_user_in_admin_records(uuid)') is null x`)).rows[0].x, true);
console.log('W7 HESAP SILME YONETIM LOCAL: TAMAM');
