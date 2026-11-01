// Yerel PostgreSQL provası: yalnız bellekte PGlite, ağ veya üretim bağlantısı yok.
// node tool/test_push_delivery_v2_local.mjs /absolute/path/to/pglite/dist/index.js
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import path from "node:path";
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) {
  throw Error("Yerel PGlite modülü için mutlak dosya yolu gerekli");
}
const { PGlite } = await import(pathToFileURL(modulePath).href);
import fs from "node:fs";
const db = await PGlite.create();
const read = (n) =>
  fs.readFileSync(new URL("../supabase/" + n, import.meta.url), "utf8");
const create = (src, name) =>
  src.match(
    new RegExp(
      "create or replace function public\\." + name +
        "\\([\\s\\S]+?\\$function\\$;",
      "i",
    ),
  )[0];
const one = async (s, args = []) => (await db.query(s, args)).rows[0];
const ok = (test, msg) => {
  if (!test) throw Error(msg);
  console.log("PASS", msg);
};
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select current_setting('test.uid', true)::uuid$$;
create table public.profiles (id uuid primary key,display_name text, fcm_token text, push_duel bool default true,push_social bool default true);
create table public.rooms(id uuid primary key default gen_random_uuid(), code text default 'TEST', status text default 'lobby', is_custom bool default true,max_players int default 8, host_id uuid, category_ids uuid[], category_id uuid, entry_fee int default 25,question_count int default 10,seconds_per_question int default 20);
create table public.room_players(room_id uuid, player_id uuid,left_at timestamptz);
create table public.friends(user_id uuid,friend_id uuid);
create table public.blocked_users(blocker_id uuid,blocked_id uuid);
create table public.room_kicks(room_id uuid,player_id uuid);
create table public.categories(id uuid,name text);
create table public.push_outbox(id uuid primary key default gen_random_uuid(),to_user_id uuid,kind text,title text,body text,from_user_id uuid,created_at timestamptz default now(),claimed_at timestamptz);
create function public.room_category_label(uuid[],text) returns text language sql as $$select coalesce($2,'test')$$;`);
const old = read("2026-10-18_oda_davet.sql");
await db.exec(
  old.slice(
    old.indexOf("create table if not exists public.room_invites"),
    old.indexOf("-- 1) invite_friends_to_room"),
  ),
);
await db.exec(
  create(read("2026-10-24_bildirim_seri_eposta.sql"), "claim_push_outbox"),
);
// pg_net işlevi yalnız sayar. pg_cron işlevleri yerel tablodan başka yere yazamaz.
await db.exec(`
create schema cron; create schema net; create schema vault;
create table cron.job(jobid bigint generated always as identity primary key, jobname text, active boolean default true);
insert into cron.job(jobname) values('send-push');
create function cron.alter_job(jobid bigint, schedule text default null, command text default null, database text default null, username text default null, active boolean default null)
returns void language sql as $$update cron.job j set active=$6 where j.jobid=$1$$;
create function cron.schedule(text,text,text) returns bigint language sql as $$insert into cron.job(jobname) values($1) returning jobid$$;
create table vault.decrypted_secrets(name text, decrypted_secret text);
insert into vault.decrypted_secrets values('send_push_url','synthetic-local'),('cron_secret','synthetic-local');
create sequence net.synthetic_calls;
create function net.http_post(url text,body jsonb default '{}',params jsonb default '{}',headers jsonb default '{}',timeout_milliseconds integer default 1000)
returns bigint language sql as $$select nextval('net.synthetic_calls')$$;
insert into profiles(id,display_name,fcm_token) values(gen_random_uuid(),'test1','fixture-1'),(gen_random_uuid(),'test2','fixture-2');
`);
await assert.rejects(
  db.exec(read("2026-11-01_push_delivery_v2_closed_cutover.sql")),
  /önce denetlenmiş V2 adayı kurulmalı/,
  "G15: V2 olmadan geçiş durmalı; dosyanın varlığı kurulum sanılıyordu",
);
await db.exec("rollback");
ok(true, "G15: V2 yokken kapalı geçiş atomik olarak reddedildi");
await db.exec(read("2026-10-31_push_delivery_v2.sql"));
ok(true, "Push V2 göç dosyasının bütünü uygulandı");
await db.exec(`set zankurd.test_database='local-only';
insert into push_outbox(to_user_id,kind,body) select id,'friend_request','önceden yerel kuyrukta' from profiles order by id limit 1;
insert into blocked_users select min(id::text)::uuid,max(id::text)::uuid from profiles;`);
async function state() {
  return await one(
    `select to_jsonb((select array_agg(to_jsonb(o) order by id) from push_outbox o)) outbox,
 (select array_agg(to_jsonb(p) order by id) from profiles p) profiles,
 (select array_agg(to_jsonb(b) order by blocker_id,blocked_id) from blocked_users b) blocks,
 (select enabled from push_delivery_v2_config) gate,
 (select tgenabled from pg_trigger where tgname='trg_push_outbox_wake_v2') trigger_state,
 (select is_called from net.synthetic_calls) as stub_calls`,
  );
}
const before = await state();
ok(
  !before.gate && before.trigger_state === "O" && !before.stub_calls,
  "kapı kapalı, üretim tetikleyicisi etkin, dış çağrı yok",
);
const smoke = read("2026-10-31_push_delivery_v2_smoke.sql");
await db.exec(smoke);
ok(true, "push_delivery_v2_smoke.sql dosyasının bütünü yürüdü");
const after = await state();
ok(
  JSON.stringify(before) === JSON.stringify(after),
  "rollback sonrasında kuyruk, profiller, engel, kapı ve tetikleyici geri alındı",
);
ok(!after.stub_calls, "ağ yerine kurulan sayaç hiç çağrılmadı");
console.log((await one("select version() v")).v);
// G15 kusuru: cron durunca eski manuel worker hâlâ V1 claimed_at yazabilir.
// Sessiz kaldı: yalnız cron kapısı sınanıyor, V1 RPC yetkisi sınanmıyordu.
const cutover = "2026-11-01_push_delivery_v2_closed_cutover.sql";
await db.exec("update public.push_delivery_v2_config set enabled=true");
await db.exec(read(cutover));
await db.exec(read(cutover));
const acl = await one(`select
 has_function_privilege('service_role','public.claim_push_outbox(integer)','execute') legacy,
 has_function_privilege('service_role','public.claim_push_outbox_v2(integer)','execute') v2,
 has_function_privilege('anon','public.claim_push_outbox_v2(integer)','execute') anon,
 (select enabled from push_delivery_v2_config) gate,
 (select active from cron.job where jobname='send-push') cron`);
assert.equal(
  acl.legacy,
  false,
  "G15: cron kapalı olsa da eski worker V1 ile işi sessizce tüketiyor",
);
assert.deepEqual(acl, {
  legacy: false,
  v2: true,
  anon: false,
  gate: false,
  cron: false,
});
assert.deepEqual(
  await state(),
  before,
  "G15: geçiş eski işi replay etmemeli; yalnız başarılı gönderim testi kaybı gizliyordu",
);
for (const role of ["service_role", "anon", "authenticated"]) {
  await db.exec(`set role ${role}`);
  await assert.rejects(
    db.query("select * from public.claim_push_outbox(20)"),
    /permission denied for function claim_push_outbox/,
    "G15: eski worker gerçek RPC çağrısı engellenmeli; cron testi bunu görmüyordu",
  );
  await db.exec("reset role");
}
ok(
  true,
  "G15: iki uygulamada V1 gerçek çağrı yetkisiz, V2 kapalı, eski işler değişmedi",
);
await db.exec("update public.push_delivery_v2_config set enabled=true");
await db.exec(read("geri_al/2026-11-01_push_delivery_v2_closed_cutover.sql"));
await db.exec(read("geri_al/2026-11-01_push_delivery_v2_closed_cutover.sql"));
assert.deepEqual(await state(), before);
assert.equal(
  (await one(
    `select has_function_privilege('service_role','public.claim_push_outbox(integer)','execute') v`,
  )).v,
  false,
);
ok(
  true,
  "G15: geri durdurma iki kez güvenli, V1 tüketimi ve eski iş replay yok",
);
await db.close();
