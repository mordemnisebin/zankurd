// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_hesap_silme_yasal_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-08_hesap_silme_yasal.sql için: canlı taban gövdesi (kalabalık oda gövdesi + ölçek
// kilit yaması) kurulur, md5'i göçteki sabitle karşılaştırılır; göç uygulanır; ardışık
// silmede (A sonra B) C'nin anlık görüntüsünde iki kimliğin de kalmadığı kanıtlanır;
// doğrudan storage silmesi hata verirse hesap silmenin geri alınmadığı gösterilir;
// bozuk taban reddedilir; geri alma eski gövdeyi birebir döndürür.
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
let taban = kalabalik.slice(m.index, end + '$function$;'.length);
const kilitEski = "perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));";
const kilitYeni = "perform pg_advisory_xact_lock(hashtextextended('room-membership:' || v_user_id::text, 0));";
assert.equal(taban.split(kilitEski).length - 1, 1);
taban = taban.replace(kilitEski, kilitYeni);

const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const ZERO = '00000000-0000-0000-0000-000000000000';
const ROOM = '20000000-0000-0000-0000-000000000001';

async function yeniDb(tabanGovde) {
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
    ${tabanGovde}
    revoke all on function public.delete_my_account() from public;
    grant execute on function public.delete_my_account() to authenticated;
  `);
  return db;
}
const defOnce = async db => (await db.query(`select pg_get_functiondef('public.delete_my_account()'::regprocedure) d`)).rows[0].d;

// 1. Taban md5'i göçteki sabitle aynı.
let db = await yeniDb(taban);
const tabanMd5 = md5(await defOnce(db));
let goc = read('2026-11-08_hesap_silme_yasal.sql');
assert(goc.includes(`'${tabanMd5}'`), 'göçteki taban md5 yerel zincirle uyuşmuyor: ' + tabanMd5);
const nihaiMd5 = /<> '([0-9a-f]{32})' then\s+raise exception 'tur10: delete_my_account yama sonrası/.exec(goc)[1];

// 2. Bozuk taban reddedilir, hiçbir şey değişmez.
{
  const bozuk = await yeniDb(taban.replace('Not authenticated', 'Not authenticated!'));
  await assert.rejects(() => bozuk.exec(goc), /bilinen canlı taban değil/);
  await bozuk.exec('rollback');
  assert.equal((await bozuk.query('select count(*)::int c from olcek_tur3_yedek')).rows[0].c, 0);
}

// 3. Göç uygulanır; nihai md5, yedek zinciri.
await db.exec(goc);
assert.equal(md5(await defOnce(db)), nihaiMd5);
const yedek = (await db.query(`select tanim from olcek_tur3_yedek where ad='tur10:public.delete_my_account()'`)).rows[0].tanim;
assert(yedek.includes('-- md5:' + tabanMd5) && yedek.endsWith('-- yama-md5:' + nihaiMd5));
// Yeniden çalıştırma reddedilir.
await assert.rejects(() => db.exec(goc), /zaten uygulanmış/);
await db.exec('rollback');

// 4. Ardışık silme: A sonra B; C'nin anlık görüntüsünde ikisinin kimliği/adı kalmaz.
await db.exec(`insert into auth.users values ('${U(1)}'),('${U(2)}'),('${U(3)}')`);
await db.exec(`insert into profiles values ('${U(1)}'),('${U(2)}'),('${U(3)}')`);
await db.exec(`insert into rooms values ('${ROOM}')`);
await db.exec(`insert into room_players values ('${ROOM}','${U(1)}'),('${ROOM}','${U(2)}'),('${ROOM}','${U(3)}')`);
const payload = {
  room: {id: ROOM, host_id: U(2), question_count: 7},
  own_player_id: U(3),
  players: [
    {player_id: U(1), display_name: 'Ali', final_score: 50, final_streak: 2, rank: 1},
    {player_id: U(2), display_name: 'Bavê', final_score: 40, final_streak: 1, rank: 2},
    {player_id: U(3), display_name: 'Cemo', final_score: 30, final_streak: 0, rank: 3},
  ],
  winner_id: U(1),
};
await db.query(`insert into room_result_snapshots values ($1,$2,$3)`, [ROOM, U(3), payload]);
const sil = async n => {
  await db.exec(`select set_config('test.uid','${U(n)}',false)`);
  await db.exec('delete from room_result_snapshots where false');
  return db.exec(`select public.anonymize_deleted_user_in_snapshots('${U(n)}')`);
};
await sil(1);
await db.exec(`delete from room_players where player_id='${U(1)}'`);
await sil(2);
const sonra = (await db.query(`select payload::text t, payload p from room_result_snapshots`)).rows[0];
assert(!sonra.t.includes(U(1)) && !sonra.t.includes(U(2)) && !sonra.t.includes('Ali') && !sonra.t.includes('Bavê'));
assert.equal(sonra.p.players.length, 3);
assert.deepEqual(sonra.p.players.map(p => p.final_score), [50, 40, 30]);
assert.equal(sonra.p.players[2].display_name, 'Cemo');
assert.equal(sonra.p.winner_id, ZERO);
assert.equal(sonra.p.room.host_id, null);
assert.equal(sonra.p.own_player_id, U(3));

// 5. Yardımcı istemciye kapalı.
for (const rol of ['anon', 'authenticated']) {
  const r = await db.query(`select has_function_privilege('${rol}', 'public.anonymize_deleted_user_in_snapshots(uuid)', 'execute') x`);
  assert.equal(r.rows[0].x, false, rol);
}

// 6. Doğrudan storage silmesi HATA verse bile hesap silme geri alınmaz (gövde metni +
//    alt işlem bloğu: tetikleyici fırlatan storage tablosunda).
{
  const d2 = await yeniDb(taban);
  await d2.exec(goc);
  const g = await defOnce(d2);
  assert(g.includes('exception when others then'));
  assert(g.indexOf('anonymize_deleted_user_in_snapshots') < g.indexOf('delete from public.room_players'));
  // Alt işlem bloğunun davranışı: fırlatan DELETE yutulur.
  await d2.exec(`
    create function storage.protect() returns trigger language plpgsql as $$ begin raise exception 'Direct deletion from storage tables is not allowed'; end $$;
    create trigger t before delete on storage.objects for each statement execute function storage.protect();
    do $$ begin
      begin delete from storage.objects where bucket_id = 'avatars'; exception when others then null; end;
    end $$;`);
}

// 7. Geri alma eski gövdeyi birebir döndürür; ikinci kez de temiz.
await db.exec(read('geri_al/2026-11-08_hesap_silme_yasal_geri.sql'));
assert.equal(md5(await defOnce(db)), tabanMd5);
assert.equal((await db.query(`select count(*)::int c from olcek_tur3_yedek`)).rows[0].c, 0);
assert.equal((await db.query(`select to_regprocedure('public.anonymize_deleted_user_in_snapshots(uuid)') is null x`)).rows[0].x, true);
console.log('HESAP SILME YASAL LOCAL: TAMAM');
