// Yerel PostgreSQL bekçisi: ağ/üretim bağlantısı yok; PGlite bellek DB.
// node tool/test_room_duel_guards_local.mjs /absolute/path/to/pglite/dist/index.js
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const one = async (sql, args=[]) => (await db.query(sql,args)).rows[0];
const fn = (src, name, delimiter='$function$') => {
  const start = new RegExp('create or replace function public\\.'+name+'\\(', 'i').exec(src)?.index ?? -1;
  assert(start >= 0, name);
  const body = src.indexOf(delimiter,start);
  return src.slice(start,src.indexOf(delimiter+';',body+delimiter.length)+delimiter.length+1);
};
const uid='10000000-0000-0000-0000-000000000001';
const room='20000000-0000-0000-0000-000000000001';
const q0='30000000-0000-0000-0000-000000000001';
const q1='30000000-0000-0000-0000-000000000002';
const duel='40000000-0000-0000-0000-000000000001';
await db.exec(`
create role anon; create role authenticated; create role service_role;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select current_setting('test.uid',true)::uuid$$;
create table profiles(id uuid primary key);
insert into profiles values('${uid}');
set test.uid='${uid}';
create table rooms(id uuid primary key,host_id uuid,status text,current_question_index integer);
insert into rooms values('${room}','${uid}','active',0);
create table room_players(room_id uuid,player_id uuid);
insert into room_players values('${room}','${uid}');
create table categories(id uuid primary key,name text);
create table questions(id uuid primary key,category_id uuid,prompt text,option_a text,option_b text,option_c text,option_d text,question_type text,image_url text,difficulty integer,correct_option text);
insert into questions(id,prompt,option_a,option_b,correct_option) values('${q0}','CURRENT','A0','B0','A'),('${q1}','FUTURE','A1','B1','B');
create table room_questions(room_id uuid,question_id uuid,question_index integer,started_at timestamptz);
insert into room_questions values('${room}','${q0}',0,now()),('${room}','${q1}',1,null);
create table room_invites(invitee_id uuid,status text,room_id uuid);
create table async_duels(id uuid primary key,creator_id uuid,opponent_id uuid,status text,expires_at timestamptz,question_ids uuid[]);
insert into async_duels values('${duel}','${uid}',null,'open',now()+interval '1 day',array['${q0}','${q1}']::uuid[]);
create table async_duel_answers(duel_id uuid,player_id uuid,question_index integer);
create table async_duel_question_starts(duel_id uuid,player_id uuid,question_index integer,started_at timestamptz,primary key(duel_id,player_id,question_index));
create function join_room_by_code(p_code text) returns json language plpgsql security definer set search_path=public as $$begin
 if p_code <> 'RIGHT' then raise exception 'Room not found or already started'; end if;
 return json_build_object('room_id','${room}','live_sentinel',42);
end$$;
`);
const invite=read('2026-10-18_oda_davet.sql');
await db.exec(invite.slice(invite.indexOf('create table if not exists public.room_code_misses'),invite.indexOf('-- Doğrulama:')));
await db.exec(read('2026-09-06_get_room_questions_revealed.sql'));
await db.exec(fn(read('2026-10-24_duello_sirasi.sql'),'present_async_duel_question'));
// Tam güncel answer gövdesi çok sayıda ödül tablosuna bağlıdır. Burada eski
// süre kusurunu taşıyan minimal çekirdek vardır; yeni göçün tamamı yürütülür.
await db.exec(`create function answer_async_duel(p_duel_id uuid,p_question_index integer,p_choice text,p_response_ms integer) returns jsonb
language plpgsql security definer set search_path=public as $$declare
 v_elapsed_ms integer; v_max_ms integer:=20000; v_is_correct boolean:=p_choice='A'; st timestamptz;
begin
 select started_at into st from async_duel_question_starts where duel_id=p_duel_id and player_id=auth.uid() and question_index=p_question_index;
 if found then
 v_elapsed_ms:=extract(epoch from (clock_timestamp()-st))*1000;
 if v_elapsed_ms > v_max_ms + 5000 then v_is_correct := false; end if;
 end if;
 return jsonb_build_object('correct',v_is_correct,'live_sentinel',42);
end$$;`);
const payload=JSON.stringify({duel_id:duel,questions:[{id:q0,prompt:'CURRENT',option_a:'A0'},{id:q1,prompt:'FUTURE',option_a:'A1'}]});
for(const [name,args] of [['start_async_duel','p_category text default null'],['create_async_duel_challenge','p_category text default null,p_friend_id uuid default null'],['accept_async_duel_challenge','p_code text'],['resume_my_async_duel','p_duel_id uuid']]) {
 await db.exec(`create function ${name}(${args}) returns jsonb language sql security definer as $$select '${payload}'::jsonb$$;`);
}
// RED: eski tanımlar kusurları yeniden üretir.
await assert.rejects(db.query("select join_room_by_code('BAD')"), /Room not found/);
assert.equal((await one('select count(*)::int n from room_code_misses')).n,0);
assert.equal((await db.query('select get_room_questions($1) q',[room])).rows[1].q.prompt,'FUTURE');
assert.equal((await one(`select answer_async_duel($1,0,'A',0) result`,[duel])).result.correct,true);
console.log('RED reproduced G6/G7/G8: sayılmayan eski deneme, gelecek içerik, kayıtsız doğru');
const migration=read('2026-11-01_room_duel_guards.sql');
await db.exec(migration);
await db.exec(migration);
console.log('PASS G6/G7/G8: tam aday göç iki kez yürütüldü; eski testler yalnız dosya içeriğini okuyordu');
for(let i=0;i<20;i++) {
 const r=await one(`select join_room_by_code($1) result`,['BAD']);
 assert.equal(r.result.error,'room_not_found');
}
assert.equal((await one('select count(*)::int n from room_code_misses')).n,20);
for(const name of ['join_room_by_code','join_room_by_code_v2'])
 assert.equal((await one(`select ${name}('RIGHT') result`)).result.error,'too_many_attempts');
console.log('PASS G6: eski RPC sayacı atlayamaz; önce yalnız v2 sınanıyordu; 20 hata COMMIT sonrası korunur');
await db.exec('truncate room_code_misses');
assert.equal((await one("select join_room_by_code('RIGHT') result")).result.live_sentinel,42);
for(const name of ['join_room_by_code','join_room_by_code_v2','get_room_questions','answer_async_duel','start_async_duel','create_async_duel_challenge','accept_async_duel_challenge','resume_my_async_duel']) {
 const rows=(await db.query(`select oid::regprocedure::text signature from pg_proc where proname=$1`,['_guard_20261101_'+name])).rows;
 for(const r of rows) assert.equal((await one("select has_function_privilege('authenticated',$1,'execute') allowed",[r.signature])).allowed,false);
}
assert.equal((await one("select position('pg_advisory_xact_lock' in pg_get_functiondef('join_room_by_code_v2(text)'::regprocedure))>0 locked")).locked,true);
await db.exec("begin;select join_room_by_code('RIGHT');select join_room_by_code_v2('RIGHT')");
assert.equal((await one("select count(*)::int n from pg_locks where locktype='advisory' and granted")).n,1);
await db.exec('rollback');
console.log('PASS G6: sınırsız çekirdekler yetkisiz; ortak kilit mevcut (PGlite tek bağlantı: gerçek paralellik sınanmadı)');
let rows=(await db.query('select get_room_questions($1) q',[room])).rows.map(r=>r.q);
assert.equal(rows[0].prompt,'CURRENT'); assert.equal(rows[0].correct_option,null);
assert.deepEqual(rows[1],{id:q1,index:1,prompt:'',content_hidden:true});
await db.exec(`update room_questions set started_at=null where question_index=0`);
rows=(await db.query('select get_room_questions($1) q',[room])).rows.map(r=>r.q);
assert.equal(rows[0].prompt,'');
await db.exec(`update rooms set current_question_index=1;update room_questions set started_at=now() where question_index=1`);
rows=(await db.query('select get_room_questions($1) q',[room])).rows.map(r=>r.q);
assert.equal(rows[0].correct_option,'A'); assert.equal(rows[1].prompt,'FUTURE');
await db.exec("update rooms set status='finished'");
rows=(await db.query('select get_room_questions($1) q',[room])).rows.map(r=>r.q);
assert.equal(rows[1].correct_option,'B');
await db.exec("update rooms set status='active'");
console.log('PASS G7: gelecek içerik kapalı, başlangıçsız aktif içerik kapalı, geçmiş inceleme açık; önce yalnız doğru şık gizleniyordu');
for(const sql of ["start_async_duel()","create_async_duel_challenge()","accept_async_duel_challenge('CODE')",`resume_my_async_duel('${duel}')`]) {
 const r=(await one(`select ${sql} result`)).result;
 assert.equal(r.questions.length,2); assert.equal(r.questions[0].prompt,''); assert.equal(r.questions[1].option_a,undefined);
}
await assert.rejects(db.query(`select answer_async_duel($1,0,'A',0)`,[duel]),/Question not presented/);
let presented=(await one(`select present_async_duel_question_v2($1,0) result`,[duel])).result;
assert.equal(presented.question.prompt,'CURRENT'); assert.equal(presented.question.correct_option,undefined);
const started=presented.started_at;
presented=(await one(`select present_async_duel_question_v2($1,0) result`,[duel])).result;
assert.equal(presented.started_at,started);
await assert.rejects(db.query(`select present_async_duel_question_v2($1,1)`,[duel]),/Invalid index/);
assert.equal((await one(`select answer_async_duel($1,0,'A',0) result`,[duel])).result.correct,true);
await db.exec(`update async_duel_question_starts set started_at=now()-interval '26 seconds'`);
assert.equal((await one(`select answer_async_duel($1,0,'A',0) result`,[duel])).result.correct,false);
assert.equal((await one(`select answer_async_duel($1,1,'TIMEOUT',20000) result`,[duel])).result.correct,false);
console.log('PASS G8: kayıt zorunlu, içerik sunumla açılır, tekrar saati sıfırlamaz, 26s doğru reddi; önce kayıt yokluğu atlanıyordu');
for (const sig of ['join_room_by_code(text)','join_room_by_code_v2(text)','get_room_questions(uuid)','present_async_duel_question_v2(uuid,integer)','answer_async_duel(uuid,integer,text,integer)'])
 assert.equal((await one("select has_function_privilege('anon',$1,'execute') allowed",[sig])).allowed,false);
await db.exec("set test.uid='10000000-0000-0000-0000-000000000099'");
await assert.rejects(db.query('select get_room_questions($1)',[room]),/Player is not in the room/);
await assert.rejects(db.query('select present_async_duel_question_v2($1,0)',[duel]),/Not a duel player/);
await db.exec(`set test.uid='${uid}'`);
await db.exec(read('geri_al/2026-11-01_room_duel_guards.sql'));
assert.equal((await one(`select start_async_duel() result`)).result.questions[0].prompt,'CURRENT');
await db.exec(migration);
assert.equal((await one(`select start_async_duel() result`)).result.questions[0].prompt,'');
console.log('PASS G6/G7/G8: geri alma tam yedeği döndürdü, yeniden uygulama çalıştı');
await db.close();
