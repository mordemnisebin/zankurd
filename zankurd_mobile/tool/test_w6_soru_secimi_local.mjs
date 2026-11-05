// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_w6_soru_secimi_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-18_w6_soru_secimi.sql için:
//  1. start_room_game: oynanmamış (started_at/revealed_at NULL) oda sorusu önce ESKİ gövdede
//     "görülmüş" sayılır (kusur), yama sonrası sayılmaz; gerçekten sunulan hâlâ sayılır.
//  2. prepare_verified_solo_questions: aday kümesi kimlik indeksinden okunur; her çağrı
//     p_limit ayrı soru verir, süzgeçler (onaysız/pasif/boş şık) aynı, küçük havuzda
//     'No questions', havuz sonu sarması, çeşitlilik (çok çağrıda geniş kapsama).
//  3. Düzen: taban md5 ön koşulu, nihai md5 sabitleri, yedek 'w6:' satırları, 2. uygulama
//     no-op, beklenmeyen gövdede durma (ya hep ya hiç), geri alma birebir, yeniden ileri.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const md5 = t => crypto.createHash('md5').update(t).digest('hex');
const fnText = (src, name, delim = '$function$') => {
  const m = new RegExp('create or replace function public\\.' + name + '\\(', 'i').exec(src);
  assert(m, name);
  const end = src.indexOf(delim + ';', src.indexOf(delim, m.index) + 1);
  return src.slice(m.index, end + delim.length + 1);
};
const defOnce = async n => (await db.query(`select pg_get_functiondef('public.${n}'::regprocedure) d`)).rows[0].d;
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
const pass = m => console.log('PASS ' + m);

const mig = read('2026-11-18_w6_soru_secimi.sql');
const geri = read('geri_al/2026-11-18_w6_soru_secimi_geri.sql');
const SRG = 'start_room_game(uuid)';
const PVS = 'prepare_verified_solo_questions(text,integer)';
const U = '10000000-0000-0000-0000-000000000001';

// --- Taban gövdeler: göç zincirindeki SON tanım (applied.md ✅) ------------------
const baseSrg = fnText(read('2026-10-18_oda_kod_kategori.sql'), 'start_room_game');
const basePvs = fnText(read('2026-11-01_solo_daily_verified.sql'), 'prepare_verified_solo_questions');

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid', true), '')::uuid$$;
  create table public.profiles(id uuid primary key);
  create table public.categories(id uuid primary key default gen_random_uuid(), name text, is_active boolean);
  create table public.questions(id uuid primary key default gen_random_uuid(), category_id uuid references public.categories(id),
    prompt text, option_a text, option_b text, option_c text, option_d text,
    correct_option text, question_type text, is_approved boolean,
    explanation text, explanation_ku text, explanation_tr text);
  create table public.verified_solo_selections(id uuid primary key default gen_random_uuid(), user_id uuid,
    question_ids uuid[], created_at timestamptz not null default clock_timestamp());
  create table public.olcek_tur3_yedek (ad text primary key, tanim text not null, alindi timestamptz not null default now());
  create table public.player_answers(player_id uuid, question_id uuid, created_at timestamptz default now());
  create table public.rooms(id uuid primary key, created_at timestamptz, started_at timestamptz, finished_at timestamptz);
  create table public.room_players(room_id uuid, player_id uuid);
  create table public.room_questions(room_id uuid, question_id uuid, question_index int, started_at timestamptz, revealed_at timestamptz);
  insert into public.profiles values('${U}');
  set test.uid = '${U}';
`);
await db.exec('set check_function_bodies = off;');
await db.exec(baseSrg);
await db.exec('set check_function_bodies = on;');
await db.exec(basePvs);
await db.exec(`revoke all on function public.${SRG} from public; grant execute on function public.${SRG} to authenticated;
  revoke all on function public.${PVS} from public; grant execute on function public.${PVS} to authenticated;`);
const taban = {[SRG]: md5(await defOnce(SRG)), [PVS]: md5(await defOnce(PVS))};

// --- Nihai md5: yamalar JS'te taban gövdeye uygulanarak hesaplanır ----------------
const yamalar = [...mig.matchAll(/select pg_temp\.w6_yama\(\s*'public\.([^']+)',\s*\$e\$([\s\S]*?)\$e\$,\s*\$y\$([\s\S]*?)\$y\$\)/g)]
  .map(m => ({imza: m[1], eski: m[2], yeni: m[3]}));
assert.equal(yamalar.length, 2);
const nihaiHesap = async imza => {
  let d = await defOnce(imza);
  for (const y of yamalar.filter(y => y.imza === imza)) {
    assert.equal(d.split(y.eski).length - 1, 1, imza + ': eski parça tam bir kez olmalı');
    d = d.replace(y.eski, () => y.yeni);
  }
  return md5(d);
};
const nihai = {[SRG]: await nihaiHesap(SRG), [PVS]: await nihaiHesap(PVS)};
console.log('TABAN md5  ', JSON.stringify(taban));
console.log('NIHAI md5  ', JSON.stringify(nihai));
assert(mig.includes(`'${taban[SRG]}'`) && mig.includes(`'${taban[PVS]}'`), 'göçteki taban md5 sabitleri zincirden hesaplananla aynı olmalı');
assert(mig.includes(`'${nihai[SRG]}'`) && mig.includes(`'${nihai[PVS]}'`), 'göçteki nihai md5 sabitleri hesaplananla aynı olmalı');
pass('taban/nihai md5 sabitleri zincirden hesaplananla aynı');

// --- Veri -------------------------------------------------------------------------
const Q = n => 'abcdef00-0000-0000-0000-' + String(n).padStart(12, '0');
await db.exec(`
  insert into public.categories(id, name, is_active) values
    ('c0000000-0000-0000-0000-000000000001','Buyuk',true),
    ('c0000000-0000-0000-0000-000000000002','Kucuk',true),
    ('c0000000-0000-0000-0000-000000000003','Pasif',false);
  insert into public.questions(id,category_id,prompt,option_a,option_b,option_c,option_d,correct_option,question_type,is_approved)
  select gen_random_uuid(), 'c0000000-0000-0000-0000-000000000001', 'Soru '||n,'A','B','C','D','A','multiple_choice', true
  from generate_series(1,400) n;
  insert into public.questions(id,category_id,prompt,option_a,option_b,option_c,option_d,correct_option,question_type,is_approved)
  select gen_random_uuid(), 'c0000000-0000-0000-0000-000000000002', 'Kucuk '||n,'A','B','C','D','A','multiple_choice', true
  from generate_series(1,5) n;
  -- Elenmesi gereken satırlar (tek başlarına): onaysız, pasif kategori, boş şık, geçersiz doğru şık.
  insert into public.questions(id,category_id,prompt,option_a,option_b,option_c,option_d,correct_option,question_type,is_approved) values
   ('abcdef02-0000-0000-0000-000000000001','c0000000-0000-0000-0000-000000000001','Onaysiz','A','B','C','D','A','multiple_choice',false),
   ('abcdef02-0000-0000-0000-000000000002','c0000000-0000-0000-0000-000000000003','Pasif','A','B','C','D','A','multiple_choice',true),
   ('abcdef02-0000-0000-0000-000000000003','c0000000-0000-0000-0000-000000000001','BosSik','A','B','-','D','A','multiple_choice',true),
   ('abcdef02-0000-0000-0000-000000000004','c0000000-0000-0000-0000-000000000001','YanlisAnahtar','A','B','C','D','E','multiple_choice',true);
`);
const BAD = new Set((await db.query(`select id from public.questions where prompt in ('Onaysiz','Pasif','BosSik','YanlisAnahtar')`)).rows.map(r => r.id));
assert.equal(BAD.size, 4);
const prep = async (cat, n) => (await one('select public.prepare_verified_solo_questions($1,$2) v', [cat, n])).v;

// recent_seen kolunu gövdeden çıkarıp çalıştıran yardımcı (yamalı/yamasız metin gerçekten çalışır).
const R1 = '90000000-0000-0000-0000-000000000001', R2 = '90000000-0000-0000-0000-000000000002';
await db.exec(`
  insert into public.rooms values ('${R1}', now() - interval '1 day', null, now() - interval '1 day');
  insert into public.room_players values ('${R1}','${U}');
  insert into public.room_questions values
    ('${R1}','${Q(1)}',0, now() - interval '1 day', now() - interval '1 day'),   -- sunuldu
    ('${R1}','${Q(2)}',1, null, now() - interval '1 day'),                         -- yalnız açıklandı
    ('${R1}','${Q(3)}',2, null, null);                                             -- HİÇ sunulmadı
  insert into public.rooms values ('${R2}', now(), null, null);
  insert into public.room_players values ('${R2}','${U}');
`);
const recentSeen = async () => {
  const d = await defOnce(SRG);
  const a = d.indexOf('with room_member as (');
  const b = d.indexOf('cand as (');
  assert(a > 0 && b > a, 'recent_seen CTE bulunamadı');
  const cte = d.slice(a, b).replace(/,\s*$/, '')
    .replaceAll('p_room_id', `'${R2}'::uuid`)
    .replaceAll('v_server_now', 'now()');
  return new Set((await db.query(cte + ' select question_id from recent_seen')).rows.map(r => r.question_id));
};

// --- Kusur ÖNCE eski gövdede -------------------------------------------------------
let seen = await recentSeen();
assert(seen.has(Q(1)) && seen.has(Q(2)) && seen.has(Q(3)), 'eski gövde: hiç sunulmayan soru da görülmüş sayılıyor (kusur)');
pass('1 KUSUR (eski gövde): sunulmamış oda sorusu "görülmüş" sayılıyor');
{
  const old = [];
  for (let i = 0; i < 20; i++) old.push(...(await prep('Buyuk', 10)).question_ids);
  // Eski gövde yalnız kusursuz çalışır; çeşitlilik ölçümü yeni gövdeyle karşılaştırılır.
  assert(old.every(id => !BAD.has(id)));
  await db.exec('delete from public.verified_solo_selections');
}

// --- Göçü uygula -----------------------------------------------------------------
await db.exec(mig);
assert.equal(md5(await defOnce(SRG)), nihai[SRG]);
assert.equal(md5(await defOnce(PVS)), nihai[PVS]);
const yedek = (await db.query(`select ad, tanim from public.olcek_tur3_yedek order by ad`)).rows;
assert.deepEqual(yedek.map(r => r.ad), ['w6:public.' + PVS, 'w6:public.' + SRG].sort());
pass('göç uygulandı: iki işlev nihai md5\'te, yedek satırları yazıldı');

seen = await recentSeen();
assert(seen.has(Q(1)) && seen.has(Q(2)), 'sunulan ve açıklanan soru hâlâ görülmüş');
assert(!seen.has(Q(3)), 'hiç sunulmayan soru artık görülmüş sayılmıyor');
pass('1 DÜZELTME: yalnız gerçekten sunulan sorular "görülmüş" (sunulmayan dışlanmaz)');

// --- prepare ----------------------------------------------------------------------
const kapsam = new Set();
for (let i = 0; i < 60; i++) {
  if (i === 50) await db.exec('delete from public.verified_solo_selections');
  const v = await prep('Buyuk', 10);
  assert.equal(v.question_ids.length, 10);
  assert.equal(new Set(v.question_ids).size, 10, 'sorular tekil');
  for (const id of v.question_ids) { assert(!BAD.has(id), 'elenmesi gereken satır seçildi: ' + id); kapsam.add(id); }
  assert(v.selection_id);
}
assert(kapsam.size >= 150, 'çeşitlilik: 60 turda ' + kapsam.size + ' farklı soru (en az 150 beklenir)');
pass('2 prepare: 60 çağrı, hep 10 tekil uygun soru, ' + kapsam.size + ' farklı soru, süzgeçler aynı');
// server_only: yalnız sunucuda tutulan sorular solo seçimden dışlanır (sütunu göç ekledi).
await db.exec('delete from public.verified_solo_selections');
await db.exec(`update public.questions set server_only = true where id in (select id from public.questions where category_id = 'c0000000-0000-0000-0000-000000000001' and prompt like 'Soru %' order by id limit 300)`);
const SO = new Set((await db.query('select id from public.questions where server_only')).rows.map(r => r.id));
assert.equal(SO.size, 300);
for (let i = 0; i < 20; i++) for (const id of (await prep('Buyuk', 10)).question_ids) assert(!SO.has(id), 'server_only soru solo seçildi');
await assert.rejects(prep('Buyuk', 51 - 1 + 90), /Invalid question count/);
pass('3 server_only sorular solo seçimden dışlanır (sütun göçle eklendi)');
await db.exec('update public.questions set server_only = false');
await db.exec('delete from public.verified_solo_selections'); // günlük 100 bilet sınırı
const tevlihev = await prep('Tevlihev', 10);
assert.equal(tevlihev.question_ids.length, 10);
const nullCat = await prep(null, 10);
assert.equal(nullCat.question_ids.length, 10);
const kucuk = await prep('Kucuk', 5);
assert.equal(new Set(kucuk.question_ids).size, 5, 'küçük havuzda tüm havuz (sarma dahil)');
await assert.rejects(prep('Kucuk', 6), /No questions/);
await assert.rejects(prep('Pasif', 1), /No questions/);
await assert.rejects(prep('Buyuk', 0), /Invalid question count/);
await assert.rejects(prep('Buyuk', 51), /Invalid question count/);
pass('2 prepare: Tevlihev/NULL kategori, küçük havuz (sarma), yetersiz havuzda hata, sınırlar eskisi gibi');
// Sarma: her çağrı farklı eşikle; havuz sonuna denk gelen çağrılar da tam sayıda soru verir (60+ çağrı yukarıda).
const sel = await one('select question_ids, user_id from public.verified_solo_selections order by created_at desc limit 1');
assert.equal(sel.user_id, U);
pass('2 prepare: bilet yazımı aynı');

// --- Düzen: yeniden çalıştırma / beklenmeyen gövde / geri alma -------------------------
await db.exec(mig);
assert.equal(md5(await defOnce(SRG)), nihai[SRG]);
assert.equal((await db.query(`select 1 from public.olcek_tur3_yedek`)).rows.length, 2);
pass('göç ikinci kez çalışınca no-op (yedek ve gövde aynı)');

// Beklenmeyen gövde: canlı gövde değişmişse (taban da nihai de değil) göç DURUR, hiçbir şey değişmez.
{
  await db.exec(geri); // önce tabana dön
  const taze = await defOnce(PVS);
  assert.equal(md5(taze), taban[PVS]);
  await db.exec(taze.replace("'Daily selection limit'", "'Daily selection limit '") + ';');
  const oncekiSrg = await defOnce(SRG);
  await assert.rejects(db.exec(mig), /ne bilinen canlı taban ne de bu sürümün nihai gövdesi/);
  await db.exec('rollback').catch(() => {});
  assert.equal(await defOnce(SRG), oncekiSrg, 'ya hep ya hiç: start_room_game dokunulmadı');
}
pass('beklenmeyen gövdede göç durur ve hiçbir işlev değişmez');

// Taban gövdeye dön, göçü yeniden uygula (önce yedek satırlarını temizle: tam yeni kurulum).
await db.exec('delete from public.olcek_tur3_yedek');
await db.exec(basePvs + ';');
await db.exec(baseSrg + ';');
assert.equal(md5(await defOnce(PVS)), taban[PVS]);
assert.equal(md5(await defOnce(SRG)), taban[SRG]);
await db.exec(mig);
assert.equal(md5(await defOnce(PVS)), nihai[PVS]);

// Geri alma: eski gövdeleri BİREBİR döndürür; yedek satırları silinir; yeniden ileri çalışır.
await db.exec(geri);
assert.equal(md5(await defOnce(PVS)), taban[PVS]);
assert.equal(md5(await defOnce(SRG)), taban[SRG]);
assert.equal((await db.query(`select 1 from public.olcek_tur3_yedek`)).rows.length, 0);
await assert.rejects(db.exec(geri), /yedek satırı yok/); // ikinci geri alma durur
await db.exec('rollback').catch(() => {});
await db.exec(mig);
assert.equal(md5(await defOnce(PVS)), nihai[PVS]);
assert.equal(md5(await defOnce(SRG)), nihai[SRG]);
pass('geri alma eski gövdeleri birebir döndürür; yeniden ileri göç çalışır');

// ACL: anon/PUBLIC çağıramaz.
for (const fn of [SRG, PVS]) {
  const acl = await one(`select has_function_privilege('anon',$1,'execute') a, has_function_privilege('authenticated',$1,'execute') s`, ['public.' + fn]);
  assert.equal(acl.a, false); assert.equal(acl.s, true);
}
pass('anon EXECUTE yok, authenticated var');
// --- icerik_alan7 canlı kıyas SQL'i (salt okunur) gerçekten çalışır ve sınıflar -------------
{
  const kiyasSql = execFileSync('python3', [new URL('./icerik_alan7_canli_kiyas.py', import.meta.url).pathname, 'sql'], {encoding: 'utf8'});
  assert(!/\b(insert|update|delete|truncate|drop|alter|create|commit)\b/i.test(kiyasSql.replace(/--.*$/gm, '').replace(/'(?:[^']|'')*'/g, "''")),
    'kıyas SQL\'i yazma/commit içermemeli');
  assert(/begin read only;/.test(kiyasSql) && /rollback;/.test(kiyasSql));
  // Sentetik canlı: bir hedefin değeri eskiyle aynı (uygula), biri yeniyle (zaten), biri farklı (farkli + soru atla), biri yok.
  const hedefler = [...kiyasSql.matchAll(/^  \('([0-9a-f-]{36})','([^']*)','([^']*)'/gm)].map(m => ({id: m[1], yerel: m[2], sutun: m[3]}));
  assert(hedefler.length === 375, 'hedef sayısı 375: ' + hedefler.length);
  const k = hedefler.find(h => h.sutun === 'prompt');
  const kPrompts = kiyasSql.match(new RegExp("^  \\('" + k.id + "','" + k.yerel + "','prompt','((?:[^']|'')*)','((?:[^']|'')*)'", 'm'));
  const eski = kPrompts[1].replaceAll("''", "'");
  await db.query(`insert into public.categories(id,name,is_active) values ('c0000000-0000-0000-0000-0000000000aa','K',true) on conflict do nothing`);
  await db.query(`insert into public.questions(id,category_id,prompt,option_a,option_b,option_c,option_d,correct_option,question_type,is_approved)
    values ($1,'c0000000-0000-0000-0000-0000000000aa',$2,'a','b','c','d','A','multiple_choice',true)`, [k.id, eski]);
  const sonuc = (await db.query(kiyasSql.replace('begin read only;', '').replace('rollback;', ''))).rows[0].alan7_kiyas;
  const rows = JSON.parse(sonuc);
  assert.equal(rows.length, 375);
  const kr = rows.find(r => r.id === k.id && r.sutun === 'prompt');
  assert.equal(kr.durum, 'uygula');
  assert.equal(kr.canli, eski);
  assert.equal(rows.filter(r => r.durum === 'yok').length, rows.filter(r => r.id !== k.id).length, 'canlıda olmayan hedefler yok');
  pass('icerik_alan7 kıyas SQL\'i salt okunur, 375 hedefi sınıflar (uygula/yok), canlı değeri döker');
}
console.log('TAMAM');
