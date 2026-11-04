// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_yonetim_paneli_local.mjs /mutlak/yol/pglite/dist/index.js
//
// 2026-11-12_yonetim_paneli.sql için asıl sözleşme: YÖNETİCİ OLMAYAN HİÇBİR
// oturum hiçbir admin_* RPC'sini çalıştıramaz (42501). Sonra:
//  - anon/authenticated tablo yetkisi yok, anon'a EXECUTE yok, iç yardımcılar
//    kimseye açık değil, her admin_* SECURITY DEFINER + sabit search_path;
//  - yönetici akışları (onay/ret/düzelt/emekli/kapat, YENİ SORU doğrulaması,
//    katkıcı ödülü, ilk 3 ödülü + ikinci ödülün reddi, ilk 3 dışına ödül yok,
//    OTOMATİK ÖDÜL (varsayılan kapalı, açılıştan önceki dönem yok, ikinci
//    çalıştırma 0, elle verilmişse tekrar yok, kısıtlı hesap aday değil),
//    moderasyon, kendini/yöneticiyi moderasyondan koruma, denetim günlüğü,
//    bildirim tetikleyicisi, GERÇEK pano sayaçları + record_activity);
//  - geri alma dosyası her şeyi kaldırır, ileri göç yeniden çalışır.
// Sınır: şema sade bir taklittir (canlı tablolar değil); coin_transactions
// kısıtları ve gerçek rol/RLS davranışı canlıda ayrıca doğrulanır.
// Moderasyonun oyunda uygulanması ayrı: tool/test_yonetim_moderasyon_local.mjs.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const db = await PGlite.create();
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const forward = read('2026-11-12_yonetim_paneli.sql');
const rollback = read('geri_al/2026-11-12_yonetim_paneli_geri.sql');
const U = n => '10000000-0000-0000-0000-' + String(n).padStart(12, '0');
const ADMIN = 1, OTHER = 2, CONTRIB = 3, WINNER = 4, SECOND = 5, THIRD = 6, OUTSIDER = 7, ADMIN2 = 8;
const as = n => db.exec(`select set_config('test.uid', '${n ? U(n) : ''}', false)`);
const q = async (sql, args = []) => (await db.query(sql, args)).rows;
const one = async (sql, args = []) => (await q(sql, args))[0];
const call = async (sql, args = []) => (await db.query(`select ${sql} as r`, args)).rows[0].r;
const denied = async (label, sql, args = []) => {
  try { await db.query(`select ${sql}`, args); }
  catch (e) { assert.equal(e.code, '42501', `${label}: beklenen 42501, gelen ${e.code} ${e.message}`); return; }
  assert.fail(`${label}: yönetici olmayan çağrı REDDEDİLMEDİ`);
};
const raises = async (label, code, sql, args = []) => {
  try { await db.query(`select ${sql}`, args); }
  catch (e) { assert.equal(e.code, code, `${label}: ${e.code} ${e.message}`); return; }
  assert.fail(`${label}: hata beklendi (${code})`);
};

await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable
    as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
  grant usage on schema public to authenticated, anon;
  create table profiles(id uuid primary key, display_name text, coins int not null default 0,
    created_at timestamptz not null default now(), updated_at timestamptz not null default now());
  create table categories(id uuid primary key default gen_random_uuid(), name text, slug text);
  create function app_today() returns date language sql stable
    as $$ select (now() at time zone 'Europe/Istanbul')::date $$;
  create table questions(id uuid primary key default gen_random_uuid(), category_id uuid, prompt text,
    option_a text, option_b text, option_c text, option_d text, correct_option text, explanation text,
    difficulty int, is_approved boolean default false, review_status text, created_by uuid,
    updated_at timestamptz default now(), language_code text default 'ku-kmr', explanation_ku text,
    explanation_tr text, question_type text default 'multiple_choice', dialect text,
    quality_version int default 0, last_content_check_at timestamptz, source_title text);
  create table suggested_questions(id uuid primary key default gen_random_uuid(), user_id uuid, category text,
    prompt text, option_a text, option_b text, option_c text, option_d text, correct_option text,
    explanation text, difficulty int default 3, status text default 'pending', created_at timestamptz default now(),
    reviewed_by uuid, reviewed_at timestamptz, review_note text);
  create table question_reports(id uuid primary key default gen_random_uuid(), question_id uuid, reporter_id uuid,
    reason text, status text default 'open', created_at timestamptz default now());
  create table profile_reports(id uuid primary key default gen_random_uuid(), reporter_id uuid, reported_id uuid,
    reason text, created_at timestamptz default now());
  create table coin_transactions(id uuid primary key default gen_random_uuid(), player_id uuid, amount int, reason text,
    created_at timestamptz default now());
  create table rooms(id uuid primary key default gen_random_uuid(), created_at timestamptz default now());
  create table tournaments(id uuid primary key default gen_random_uuid(), opened_at timestamptz default now());
  create table contests(id uuid primary key default gen_random_uuid(), day_key date, rank1_reward int default 500,
    rank2_reward int default 300, rank3_reward int default 100);
  create table contest_entries(id uuid primary key default gen_random_uuid(), contest_id uuid, user_id uuid,
    score int default 0, finished_at timestamptz, created_at timestamptz default now());
  create table contest_badges(id uuid primary key default gen_random_uuid(), slug text);
  create table user_contest_badges(id uuid primary key default gen_random_uuid(), user_id uuid, badge_id uuid,
    contest_id uuid not null);
  create table async_duels(id uuid primary key default gen_random_uuid(), creator_id uuid,
    created_at timestamptz default now());
  create table verified_daily_event_results(day date not null, user_id uuid not null, correct_count int not null,
    total_count int default 10, seconds int not null, created_at timestamptz not null default clock_timestamp(),
    primary key(day, user_id));
  create table daily_event_results(day date not null, user_id uuid not null, correct_count int not null,
    total_count int default 10, seconds int not null, created_at timestamptz not null default clock_timestamp(),
    primary key(day, user_id));
  create table player_score_daily(player_id uuid not null, day date not null, score bigint not null default 0,
    primary key(player_id, day));
  create table push_outbox(id uuid primary key default gen_random_uuid(), to_user_id uuid, kind text, title text,
    body text, created_at timestamptz default now(), claimed_at timestamptz);
`);
for (let i = 1; i <= 8; i++) {
  await db.query('insert into auth.users values ($1)', [U(i)]);
  await db.query('insert into profiles(id, display_name) values ($1, $2)', [U(i), 'Oyuncu' + i]);
}
const cat = (await one(`insert into categories(name, slug) values ('Dîrok', 'dirok') returning id`)).id;
const sug = async (prompt, category = 'Dîrok', user = CONTRIB) =>
  (await one(`insert into suggested_questions(user_id, category, prompt, option_a, option_b, option_c, option_d, correct_option)
              values ($1, $2, $3, 'a1', 'b1', 'c1', 'd1', 'A') returning id`, [U(user), category, prompt])).id;

await db.exec(forward);

// ── 1. Sözleşme: yetki yapısı ────────────────────────────────────────
const fns = await q(`select p.proname, p.oid::regprocedure::text sig, p.prosecdef, p.proconfig
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and (p.proname like 'admin\\_%' or p.proname like '\\_admin\\_%'
    or p.proname in ('user_is_restricted', 'record_activity'))`);
assert(fns.length >= 28, 'admin işlevleri kurulmadı: ' + fns.length);
const internal = new Set(['admin_assert', 'admin_log', '_admin_credit_coins', 'admin_enqueue_push',
  '_admin_reward_key', '_admin_reward_coins', '_admin_reward_top3', '_admin_auto_grant',
  'admin_run_auto_rewards', 'user_is_restricted']);
for (const f of fns) {
  assert(f.prosecdef, `${f.sig} SECURITY DEFINER değil`);
  assert((f.proconfig || []).some(c => c.startsWith('search_path=')), `${f.sig} search_path sabit değil`);
  const anon = (await one(`select has_function_privilege('anon', $1::regprocedure, 'execute') v`, [f.sig])).v;
  const pub = (await one(`select has_function_privilege('public', $1::regprocedure, 'execute') v`, [f.sig])).v;
  const auth = (await one(`select has_function_privilege('authenticated', $1::regprocedure, 'execute') v`, [f.sig])).v;
  assert(!anon, `${f.sig} anon EXECUTE`);
  assert(!pub, `${f.sig} PUBLIC EXECUTE`);
  assert.equal(auth, !internal.has(f.proname), `${f.sig} authenticated yetkisi beklenenden farklı`);
  // anon/PUBLIC hiçbirine (record_activity dahil) EXECUTE alamaz: kimliksiz çağrı yok.
}
for (const t of ['admins', 'admin_audit_log', 'admin_reward_grants', 'admin_contributor_rewards',
                 'user_moderation', 'admin_settings', 'admin_notify_prefs', 'usage_daily_active',
                 'usage_mode_counter']) {
  const r = await one(`select c.relrowsecurity rls,
      has_table_privilege('anon', $1, 'select,insert,update,delete') a,
      has_table_privilege('authenticated', $1, 'select,insert,update,delete') b
      from pg_class c where c.oid = $1::regclass`, ['public.' + t]);
  assert(r.rls && !r.a && !r.b, `${t}: RLS/yetki sözleşmesi bozuk`);
}

// ── 2. Yönetici OLMAYAN her RPC'de reddedilir ────────────────────────
await db.query('insert into admins(user_id) values ($1), ($2)', [U(ADMIN), U(ADMIN2)]);
const X = U(OUTSIDER), Q = '20000000-0000-0000-0000-000000000001';
const rpcs = [
  ['admin_get_stats', 'public.admin_get_stats()'],
  ['admin_list_audit', 'public.admin_list_audit(5)'],
  ['admin_list_suggestions', "public.admin_list_suggestions('pending', 50)"],
  ['admin_review_suggestion', `public.admin_review_suggestion('${Q}', 'approve', null, null)`],
  ['admin_list_reported_questions', 'public.admin_list_reported_questions(50)'],
  ['admin_fix_question', `public.admin_fix_question('${Q}', 'x', array['a','b','c','d'], 0, null)`],
  ['admin_retire_question', `public.admin_retire_question('${Q}', null)`],
  ['admin_dismiss_question_reports', `public.admin_dismiss_question_reports('${Q}')`],
  ['admin_add_question', `public.admin_add_question('Dîrok', 'Soru?', array['a','b','c','d'], 0, 'a', null, 3)`],
  ['admin_list_contributors', 'public.admin_list_contributors(50)'],
  ['admin_reward_contributor', `public.admin_reward_contributor('${X}', 100, null)`],
  ['admin_list_reward_candidates', "public.admin_list_reward_candidates('daily', null)"],
  ['admin_grant_reward', `public.admin_grant_reward('daily', '2026-11-12', '${X}', 100, null)`],
  ['admin_get_auto_reward', 'public.admin_get_auto_reward()'],
  ['admin_set_auto_reward', 'public.admin_set_auto_reward(false)'],
  ['admin_list_user_reports', 'public.admin_list_user_reports(50)'],
  ['admin_moderate_user', `public.admin_moderate_user('${X}', 'warn', null, null)`],
  ['admin_get_notify_prefs', 'public.admin_get_notify_prefs()'],
  ['admin_set_notify_pref', "public.admin_set_notify_pref('suggestion', false)"],
];
// Liste, kurulu admin_* işlevlerinin tamamını kapsamalı (yeni RPC eklenip testlenmemesin).
const covered = new Set(rpcs.map(r => r[0]).concat(['admin_is_admin', 'record_activity', ...internal]));
for (const f of fns) assert(covered.has(f.proname), `${f.proname} için yönetici-değil testi yok`);
for (const uid of [OTHER, CONTRIB, null]) {
  await as(uid);
  for (const [name, sql] of rpcs) await denied(`${name} (uid=${uid})`, sql);
}
await as(OTHER);
assert.equal(await call('public.admin_is_admin()'), false);
await as(null);
assert.equal(await call('public.admin_is_admin()'), false);
await as(ADMIN);
assert.equal(await call('public.admin_is_admin()'), true);
// Reddedilen çağrılar hiçbir şey yazmadı.
assert.equal((await one('select count(*)::int n from admin_audit_log')).n, 0);

// ── 3. Yönetici akışları ─────────────────────────────────────────────
await as(ADMIN);
let stats = await call('public.admin_get_stats()');
assert.equal(stats.total_users, 8);
assert.equal(stats.crashes_week, null);
assert.equal(stats.active_today, 0); assert.equal(stats.active_week, 0);
assert.deepEqual(stats.mode_usage, {solo: 0, room: 0, duel: 0, tournament: 0, contest: 0});
// Gerçek sayaç: record_activity gün başına kişi başına TEK satır, solo yalnız bayrakla artar.
await as(OTHER);
await db.query('select public.record_activity(false)');
await db.query('select public.record_activity(false)');
await db.query('select public.record_activity(true)');
await db.query('select public.record_activity(true)');
await as(CONTRIB);
await db.query('select public.record_activity()');
await as(null);
await db.query('select public.record_activity(true)');            // kimliksiz: sessizce yok sayılır
assert.equal((await one('select count(*)::int n from usage_daily_active')).n, 2);
await q(`insert into usage_daily_active(day, user_id) values (app_today() - 3, $1), (app_today() - 9, $2)`, [U(WINNER), U(SECOND)]);
await q(`insert into rooms default values`); await q(`insert into rooms default values`);
await q(`insert into async_duels(creator_id) values ($1)`, [U(OTHER)]);
await q(`insert into tournaments default values`);
await q(`insert into tournaments(opened_at) values (now() - interval '30 days')`);   // hafta dışı sayılmaz
await as(ADMIN);
stats = await call('public.admin_get_stats()');
assert.equal(stats.active_today, 2);
assert.equal(stats.active_week, 3, 'son 7 gün: bugün 2 + 3 gün önceki 1; 9 gün önceki sayılmaz');
assert.deepEqual(stats.mode_usage, {solo: 2, room: 2, duel: 1, tournament: 1, contest: 0});
assert.equal(stats.new_today, 8);
assert.equal(Object.keys(stats).filter(k => /user_id|name|email/.test(k)).length, 0, 'panoya kişisel veri sızdı');


// Öneri: onay (düzeltmeli), ret, çift inceleme, bilinmeyen kategori.
const s1 = await sug('Öneri bir'), s2 = await sug('Öneri iki'), s3 = await sug('Öneri üç', 'Yok');
assert.equal((await call("public.admin_list_suggestions('pending', 50)")).length, 3);
const ap = await call(`public.admin_review_suggestion('${s1}', 'approve', 'tamam', '{"prompt":"Düzeltilmiş","options":["x","y","z","w"],"correct":2}'::jsonb)`);
assert.equal(ap.status, 'approved');
const created = await one('select * from questions where id = $1', [ap.question_id]);
assert.equal(created.prompt, 'Düzeltilmiş');
assert.equal(created.correct_option, 'C');
assert.equal(created.is_approved, true);
assert.equal(created.created_by, U(CONTRIB));
await raises('çift inceleme', '22023', `public.admin_review_suggestion('${s1}', 'approve', null, null)`);
await raises('bilinmeyen kategori', 'P0002', `public.admin_review_suggestion('${s3}', 'approve', null, null)`);
assert.equal((await one('select status from suggested_questions where id = $1', [s3])).status, 'pending');
assert.equal((await call(`public.admin_review_suggestion('${s2}', 'reject', 'zayıf', null)`)).status, 'rejected');
await raises('kötü karar', '22023', `public.admin_review_suggestion('${s3}', 'maybe', null, null)`);
await raises('kötü düzeltme', '22023', `public.admin_review_suggestion('${s3}', 'approve', null, '{"options":["a","","c","d"]}'::jsonb)`);

// Bildirilen soru: düzelt / emekli et / kapat.
const qa = (await one(`insert into questions(category_id, prompt, option_a, option_b, option_c, option_d, correct_option, is_approved)
  values ($1, 'Q-A', 'a', 'b', 'c', 'd', 'B', true) returning id`, [cat])).id;
const qb = (await one(`insert into questions(category_id, prompt, option_a, option_b, option_c, option_d, correct_option, is_approved)
  values ($1, 'Q-B', 'a', 'b', 'c', 'd', 'A', true) returning id`, [cat])).id;
const qc = (await one(`insert into questions(category_id, prompt, option_a, option_b, option_c, option_d, correct_option, is_approved)
  values ($1, 'Q-C', 'a', 'b', 'c', 'd', 'A', true) returning id`, [cat])).id;
for (const id of [qa, qa, qb, qc]) await q(`insert into question_reports(question_id, reporter_id, reason) values ($1, $2, 'yanlış')`, [id, U(OTHER)]);
const reported = await call('public.admin_list_reported_questions(50)');
assert.equal(reported.length, 3);
assert.equal(reported[0].report_count, 2);
await call(`public.admin_fix_question('${qa}', 'Q-A düz', array['1','2','3','4'], 3, 'not')`);
assert.equal((await one('select prompt, correct_option from questions where id = $1', [qa])).correct_option, 'D');
await raises('kötü düzeltme (şık sayısı)', '22023', `public.admin_fix_question('${qa}', 'x', array['1','2'], 0, null)`);
await call(`public.admin_retire_question('${qb}', 'hatalı')`);
const retired = await one('select is_approved, review_status from questions where id = $1', [qb]);
assert.equal(retired.is_approved, false);
assert.equal(retired.review_status, 'rejected');
await call(`public.admin_dismiss_question_reports('${qc}')`);
assert.equal((await call('public.admin_list_reported_questions(50)')).length, 0);
assert.equal((await one(`select status from question_reports where question_id = $1`, [qc])).status, 'dismissed');
await raises('olmayan soru', 'P0002', `public.admin_retire_question('${Q}', null)`);

// Yeni soru ekleme (panelden): doğrulama sunucuda.
const optsOk = "array['Şerefxanê Bidlîsî','Ehmedê Xanî','Melayê Cizîrî','Feqî']";
const added = await call(`public.admin_add_question('Dîrok', '  Şerefname kê nivîsand?  ', ${optsOk}, 0, 'Şerefxan 1597an nivîsî.', 'Şerefxan 1597de yazdı.', 4)`);
const nq = await one('select * from questions where id = $1', [added.question_id]);
assert.equal(nq.prompt, 'Şerefname kê nivîsand?');
assert.equal(nq.correct_option, 'A'); assert.equal(nq.option_d, 'Feqî');
assert.equal(nq.is_approved, true); assert.equal(nq.review_status, 'approved');
assert.equal(nq.created_by, U(ADMIN)); assert.equal(nq.difficulty, 4);
assert.equal(nq.explanation, 'Şerefxan 1597an nivîsî.'); assert.equal(nq.explanation_tr, 'Şerefxan 1597de yazdı.');
assert.equal(nq.language_code, 'ku-kmr'); assert.equal(nq.dialect, 'Kurmancî'); assert.equal(nq.quality_version, 2);
assert.equal((await call(`public.admin_add_question('dirok', 'Başka soru?', ${optsOk}, 3, null, 'Yalnız Türkçe', 99)`)).question_id.length, 36, 'slug ile kategori');
assert.equal((await one(`select difficulty, explanation from questions where prompt = 'Başka soru?'`)).difficulty, 5, 'zorluk 1..5 kırpılır');
const qBefore = (await one('select count(*)::int n from questions')).n;
await raises('aynı soru', '23505', `public.admin_add_question('Dîrok', 'şerefname kê nivîsand?', ${optsOk}, 0, 'x', null, 3)`);
await raises('3 şık', '22023', `public.admin_add_question('Dîrok', 'Q?', array['a','b','c'], 0, 'x', null, 3)`);
await raises('boş şık', '22023', `public.admin_add_question('Dîrok', 'Q?', array['a','b',' ','d'], 0, 'x', null, 3)`);
await raises('tekrar eden şık', '22023', `public.admin_add_question('Dîrok', 'Q?', array['a','B','c','b '], 0, 'x', null, 3)`);
await raises('doğru şık 4', '22023', `public.admin_add_question('Dîrok', 'Q?', array['a','b','c','d'], 4, 'x', null, 3)`);
await raises('doğru şık yok', '22023', `public.admin_add_question('Dîrok', 'Q?', array['a','b','c','d'], null, 'x', null, 3)`);
await raises('boş metin', '22023', `public.admin_add_question('Dîrok', '  ', array['a','b','c','d'], 0, 'x', null, 3)`);
await raises('açıklama yok', '22023', `public.admin_add_question('Dîrok', 'Q?', array['a','b','c','d'], 0, ' ', '', 3)`);
await raises('kategori yok', 'P0002', `public.admin_add_question('Yok', 'Q?', array['a','b','c','d'], 0, 'x', null, 3)`);
assert.equal((await one('select count(*)::int n from questions')).n, qBefore, 'reddedilen soru yazıldı');

// Katkıcı ödülü.
const contributors = await call('public.admin_list_contributors(50)');
const me = contributors.find(c => c.user_id === U(CONTRIB));
assert.equal(me.suggested, 3); assert.equal(me.approved, 1); assert.equal(me.rewarded_coins, 0);
await call(`public.admin_reward_contributor('${U(CONTRIB)}', 100, null)`);
assert.equal((await one('select coins from profiles where id = $1', [U(CONTRIB)])).coins, 100);
assert.equal((await one(`select count(*)::int n from coin_transactions where player_id = $1 and reason = 'admin_contributor_reward'`, [U(CONTRIB)])).n, 1);
await raises('katkıcı değil', 'P0002', `public.admin_reward_contributor('${U(OUTSIDER)}', 100, null)`);
await raises('uçuk jeton', '22023', `public.admin_reward_contributor('${U(CONTRIB)}', 999999, null)`);
assert.equal((await call('public.admin_list_contributors(50)')).find(c => c.user_id === U(CONTRIB)).rewarded_coins, 100);

// Günün yarışması ödülü (doğrulanmış sonuçlar; eski beyan tablosu yalnız geçiş öncesi günler).
const today = (await one('select app_today()::text d')).d;
const yday = (await one('select (app_today() - 1)::text d')).d;
const dev = (tbl, d, u, correct, secs) =>
  q(`insert into ${tbl}(day, user_id, correct_count, seconds) values ($1, $2, $3, $4)`, [d, U(u), correct, secs]);
const day = yday;
await dev('verified_daily_event_results', day, WINNER, 10, 40);
await dev('verified_daily_event_results', day, SECOND, 10, 55);   // aynı doğru, daha yavaş
await dev('verified_daily_event_results', day, THIRD, 8, 30);
await dev('verified_daily_event_results', day, OUTSIDER, 2, 20);
await dev('daily_event_results', day, OTHER, 10, 1);               // doğrulanmış gün olduğundan eski tablo YOK sayılır
const badge = (await one(`insert into contest_badges(slug) values ('gun-birincisi') returning id`)).id;
const contest = (await one(`insert into contests(day_key) values ($1) returning id`, [day])).id;
const cands = await call(`public.admin_list_reward_candidates('daily', '${day}')`);
assert.equal(cands.candidates.length, 3);
assert.deepEqual(cands.candidates.map(c => c.user_id), [U(WINNER), U(SECOND), U(THIRD)]);
assert.deepEqual(cands.suggested_coins, [500, 300, 100]);
assert.equal(cands.candidates[0].score, 10);
const g1 = await call(`public.admin_grant_reward('daily', '${day}', '${U(WINNER)}', 500, 'gun-birincisi')`);
assert.equal(g1.granted, true); assert.equal(g1.rank, 1);
assert.equal((await one('select coins from profiles where id = $1', [U(WINNER)])).coins, 500);
assert.equal((await one('select count(*)::int n from user_contest_badges where user_id = $1', [U(WINNER)])).n, 1);
const g2 = await call(`public.admin_grant_reward('daily', '${day}', '${U(WINNER)}', 500, null)`);
assert.equal(g2.granted, false);
assert.equal((await one('select coins from profiles where id = $1', [U(WINNER)])).coins, 500, 'ikinci ödül jeton verdi');
await raises('ilk 3 dışı', '22023', `public.admin_grant_reward('daily', '${day}', '${U(OUTSIDER)}', 100, null)`);
await raises('eski tablodaki kişi (doğrulanmış gün)', '22023', `public.admin_grant_reward('daily', '${day}', '${U(OTHER)}', 100, null)`);
await raises('hiçbir şey', '22023', `public.admin_grant_reward('daily', '${day}', '${U(SECOND)}', 0, null)`);
await raises('uçuk jeton', '22023', `public.admin_grant_reward('daily', '${day}', '${U(SECOND)}', 99999, null)`);
await raises('kötü gün', '22023', `public.admin_list_reward_candidates('daily', 'dün')`);
assert.equal((await call(`public.admin_list_reward_candidates('daily', '${day}')`)).candidates[0].rewarded, true);
// Doğrulama öncesi gün: yalnız eski beyan tablosu okunur.
const old = (await one(`select (app_today() - 40)::text d`)).d;
await dev('daily_event_results', old, OTHER, 7, 50);
assert.deepEqual((await call(`public.admin_list_reward_candidates('daily', '${old}')`)).candidates.map(c => c.user_id), [U(OTHER)]);

// Haftalık: rozet yok; ilk 3 player_score_daily hafta toplamından (pazartesi, İstanbul).
const wk = (await one(`select date_trunc('week', (app_today() - 7)::timestamp)::date::text d`)).d;
const sc = (u, off, v) => q('insert into player_score_daily(player_id, day, score) values ($1, ($2::date + $3::int), $4)', [U(u), wk, off, v]);
await sc(SECOND, 0, 3000); await sc(SECOND, 6, 2240);       // 5240
await sc(WINNER, 2, 4980); await sc(THIRD, 3, 4410); await sc(OUTSIDER, 1, 1);
await sc(OTHER, 7, 99999);                                  // hafta DIŞI (bir sonraki pazartesi)
const wc = await call(`public.admin_list_reward_candidates('weekly', '${wk}')`);
assert.deepEqual(wc.candidates.map(c => c.user_id), [U(SECOND), U(WINNER), U(THIRD)]);
assert.equal(wc.candidates[0].score, 5240);
const midweek = (await one(`select ('${wk}'::date + 3)::text d`)).d;
assert.equal((await call(`public.admin_list_reward_candidates('weekly', '${midweek}')`)).period_key, wk, 'hafta ortası günü pazartesiye yuvarlanmalı');
await raises('haftalık rozet', '22023', `public.admin_grant_reward('weekly', '${wk}', '${U(SECOND)}', 0, 'gun-birincisi')`);
assert.equal((await call(`public.admin_grant_reward('weekly', '${midweek}', '${U(SECOND)}', 1000, null)`)).granted, true);
assert.equal((await call(`public.admin_grant_reward('weekly', '${wk}', '${U(SECOND)}', 1000, null)`)).granted, false, 'hafta ortası anahtarıyla ikinci kez verilebildi');
await raises('kötü tür', '22023', `public.admin_list_reward_candidates('monthly', null)`);

// Otomatik ödül: varsayılan KAPALI; açınca yalnız açıldığı günden sonra biten dönemler.
assert.equal(await call('public.admin_get_auto_reward()'), false);
await as(null);
assert.equal((await one('select public.admin_run_auto_rewards() r')).r.enabled, false, 'kapalıyken ödül verildi');
await as(ADMIN);
// Kapalıyken HİÇ ödül çıkmadı (dünkü THIRD/SECOND hâlâ ödülsüz).
assert.equal((await one(`select count(*)::int n from admin_reward_grants where source = 'auto'`)).n, 0);
await call('public.admin_set_auto_reward(true)');
assert.equal(await call('public.admin_get_auto_reward()'), true);
// Açıldığı gün = bugün: dün ve geçen hafta "açılıştan ÖNCE" bitti -> geçmişe dönük ödül yok.
await as(null);
assert.equal((await one('select public.admin_run_auto_rewards() r')).r.granted, 0, 'geçmişe dönük ödül çıktı');
// Açılış tarihini bir hafta geriye çek (sahibin geçen hafta açmış olması): dün ve geçen hafta kapsanır.
await q(`update admin_settings set value = to_jsonb((app_today() - 14)::text) where key = 'auto_reward_since'`);
const r1 = (await one('select public.admin_run_auto_rewards() r')).r;
// Dün: WINNER elle ödüllenmişti -> atlanır; SECOND ve THIRD otomatik. Geçen hafta: SECOND elle
// ödüllenmişti -> atlanır; WINNER ve THIRD otomatik. Önceki hafta/gün boş.
assert.equal(r1.granted, 4, 'otomatik ödül sayısı ' + JSON.stringify(r1));
const autos = await q(`select period_kind, user_id, rank, coins, granted_by from admin_reward_grants where source = 'auto' order by period_kind, rank`);
assert.deepEqual(autos.map(a => [a.period_kind, a.user_id, a.rank, a.coins]),
  [['daily', U(SECOND), 2, 300], ['daily', U(THIRD), 3, 100], ['weekly', U(WINNER), 2, 600], ['weekly', U(THIRD), 3, 300]]);
for (const a of autos) assert.equal(a.granted_by, null);
assert.equal((await one('select coins from profiles where id = $1', [U(THIRD)])).coins, 400, 'THIRD günlük 100 + haftalık 300');
assert.equal((await one('select coins from profiles where id = $1', [U(WINNER)])).coins, 1100, 'WINNER: elle 500 + haftalık otomatik 600');
// İKİNCİ çalıştırma: hiçbir şey eklenmez, jeton değişmez (idempotent).
const before = (await one('select sum(coins)::int s from profiles')).s;
assert.equal((await one('select public.admin_run_auto_rewards() r')).r.granted, 0);
assert.equal((await one('select sum(coins)::int s from profiles')).s, before);
assert.equal((await one(`select count(*)::int n from admin_reward_grants`)).n, 6, 'defter satır sayısı');
// Denetim satırı yönetici kimliği olmadan yazıldı.
assert.equal((await one(`select count(*)::int n from admin_audit_log where action = 'reward_auto' and admin_id is null`)).n, 4);
await as(ADMIN);
// Kısıtlı hesap ödül adayı olamaz: THIRD'i engelle -> dün/hafta sıralaması kayar.
await q(`insert into user_moderation(user_id, state, updated_by) values ($1, 'blocked', $2)`, [U(THIRD), U(ADMIN)]);
assert.deepEqual((await call(`public.admin_list_reward_candidates('daily', '${day}')`)).candidates.map(c => c.user_id), [U(WINNER), U(SECOND), U(OUTSIDER)],
  'engelli hesap ödül adayı');
await q(`delete from user_moderation where user_id = $1`, [U(THIRD)]);
await call('public.admin_set_auto_reward(false)');
assert.equal(await call('public.admin_get_auto_reward()'), false);

// Moderasyon.
await q(`insert into profile_reports(reporter_id, reported_id, reason) values ($1, $2, 'Uygunsuz ad'), ($3, $2, 'Uygunsuz ad')`, [U(OTHER), U(OUTSIDER), U(CONTRIB)]);
let reps = await call('public.admin_list_user_reports(50)');
assert.equal(reps.length, 1);
assert.equal(reps[0].open_reports, 2);
assert.equal(Object.keys(reps[0]).some(k => k.includes('reporter')), false, 'şikâyet eden sızdı');
await raises('kendini', '42501', `public.admin_moderate_user('${U(ADMIN)}', 'block', null, null)`);
await raises('başka yönetici', '42501', `public.admin_moderate_user('${U(ADMIN2)}', 'block', null, null)`);
await raises('süresiz askı', '22023', `public.admin_moderate_user('${U(OUTSIDER)}', 'suspend', null, null)`);
await raises('kötü eylem', '22023', `public.admin_moderate_user('${U(OUTSIDER)}', 'ban', null, null)`);
await call(`public.admin_moderate_user('${U(OUTSIDER)}', 'suspend', 7, 'not')`);
reps = await call('public.admin_list_user_reports(50)');
assert.equal(reps[0].state, 'suspended'); assert.equal(reps[0].open_reports, 0);
assert((await one(`select until > now() + interval '6 days' ok from user_moderation where user_id = $1`, [U(OUTSIDER)])).ok);
await call(`public.admin_moderate_user('${U(OUTSIDER)}', 'lift', null, null)`);
assert.equal((await call('public.admin_list_user_reports(50)')).length, 0);

// Denetim günlüğü: her yazma işlemi bir satır bıraktı, yönetici kimliğiyle.
const audit = await q('select action, admin_id from admin_audit_log order by id');
for (const a of audit) assert(a.admin_id === U(ADMIN) || (a.action === 'reward_auto' && a.admin_id === null), 'denetim kimliği: ' + a.action);
const actions = new Set(audit.map(a => a.action));
for (const a of ['suggestion_approve', 'suggestion_reject', 'question_fix', 'question_retire', 'question_dismiss',
                 'contributor_reward', 'reward_grant', 'reward_auto', 'question_add', 'auto_reward_set', 'user_suspend', 'user_lift'])
  assert(actions.has(a), 'denetim satırı yok: ' + a);
const al = await call('public.admin_list_audit(100)');
assert.equal(al.length, audit.length);
assert(al.some(r => r.action === 'question_add' && r.label === 'Şerefname kê nivîsand?'), 'denetim etiketi (soru metni)');
assert(al.some(r => r.action === 'user_suspend' && r.label === 'Oyuncu7'), 'denetim etiketi (oyuncu adı)');
assert.equal((await call('public.admin_list_audit(3)')).length, 3);

// Bildirim tercihleri + tetikleyici.
assert.deepEqual(await call('public.admin_get_notify_prefs()'), {suggestion: true, report: true});
await q('delete from push_outbox');
await sug('Bildirim sınaması');
let pushes = await q('select to_user_id, kind, body from push_outbox order by to_user_id');
assert.deepEqual(pushes.map(p => p.to_user_id), [U(ADMIN), U(ADMIN2)]);
assert.equal(pushes[0].kind, 'admin_suggestion');
assert(!pushes[0].body.includes('sınaması'), 'oyuncu metni bildirime sızdı');
await call("public.admin_set_notify_pref('suggestion', false)");
assert.deepEqual(await call('public.admin_get_notify_prefs()'), {suggestion: false, report: true});
await q('delete from push_outbox');
await sug('Bildirim sınaması 2');
pushes = await q('select to_user_id from push_outbox');
assert.deepEqual(pushes.map(p => p.to_user_id), [U(ADMIN2)], 'kapalı tercih bildirim aldı');
await q('delete from push_outbox');
await q(`insert into profile_reports(reporter_id, reported_id, reason) values ($1, $2, 'x')`, [U(OTHER), U(THIRD)]);
assert.equal((await q('select 1 from push_outbox where kind = $1', ['admin_report'])).length, 2);
// Yönetici kendi önerisi için kendine bildirim almaz.
await call("public.admin_set_notify_pref('suggestion', true)");
await q('delete from push_outbox');
await q(`insert into suggested_questions(user_id, category, prompt, option_a, option_b, option_c, option_d, correct_option) values ($1, 'Dîrok', 'k2', 'a', 'b', 'c', 'd', 'A')`, [U(ADMIN2)]);
assert.deepEqual((await q('select to_user_id from push_outbox')).map(p => p.to_user_id), [U(ADMIN)]);
// Bildirim tablosu bozulsa bile asıl kayıt düşmez.
await db.exec('alter table push_outbox rename to push_outbox_x');
await sug('Bildirim kırık');
assert((await one(`select count(*)::int n from suggested_questions where prompt = 'Bildirim kırık'`)).n === 1);
await db.exec('alter table push_outbox_x rename to push_outbox');
await raises('kötü bildirim türü', '22023', "public.admin_set_notify_pref('foo', true)");

// ── 3b. Dönem sonu işi (pg_cron taklidi): kurulum, tek kopya, çalıştırılabilir, geri alma ──────
const cronFwd = read('2026-11-13_yonetim_otomatik_odul_cron.sql').replace('create extension if not exists pg_cron with schema pg_catalog;', '');
const cronRb = read('geri_al/2026-11-13_yonetim_otomatik_odul_cron_geri.sql');
await db.exec(`create schema cron;
  create table cron.job(jobid serial, jobname text, schedule text, command text);
  create function cron.schedule(n text, s text, c text) returns bigint language sql
    as $$ insert into cron.job(jobname, schedule, command) values (n, s, c) returning jobid::bigint $$;
  create function cron.unschedule(n text) returns boolean language sql
    as $$ with d as (delete from cron.job where jobname = n returning 1) select count(*) > 0 from d $$;`);
await db.exec(cronFwd);
await db.exec(cronFwd);                                              // ikinci uygulama: yine TEK kopya
let jobs = await q(`select * from cron.job where jobname = 'yonetim-otomatik-odul'`);
assert.equal(jobs.length, 1); assert.equal(jobs[0].schedule, '10 21 * * *');
assert.equal((await one('select 1 as ok from (select ' + jobs[0].command.replace(/^select /i, '') + ') x')).ok, 1, 'cron komutu çalışmıyor');
await db.exec(cronRb);
assert.equal((await q(`select 1 from cron.job where jobname = 'yonetim-otomatik-odul'`)).length, 0);

// ── 4. Geri alma ve yeniden ileri ────────────────────────────────────
await db.exec(rollback);
assert.equal((await one(`select count(*)::int n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and (p.proname like 'admin\\_%' or p.proname like '\\_admin\\_%'
    or p.proname in ('user_is_restricted', 'record_activity'))`)).n, 0);
assert.equal((await one(`select count(*)::int n from pg_tables where schemaname = 'public'
  and tablename in ('admins','admin_audit_log','admin_reward_grants','admin_contributor_rewards','user_moderation','admin_settings','admin_notify_prefs','usage_daily_active','usage_mode_counter')`)).n, 0);
assert.equal((await one(`select count(*)::int n from pg_trigger where tgname like 'trg_admin_push%'`)).n, 0);
assert.equal((await one(`select count(*)::int n from information_schema.columns where table_name = 'profile_reports' and column_name = 'handled_at'`)).n, 0);
// Geri alma asıl tablolara dokunmadı.
assert.equal((await one('select count(*)::int n from questions')).n, qBefore);
await db.exec(forward);
await db.query('insert into admins(user_id) values ($1)', [U(ADMIN)]);
await as(ADMIN);
assert.equal(await call('public.admin_is_admin()'), true);
await as(OTHER);
await denied('yeniden ileri: admin değil', 'public.admin_get_stats()');

console.log('OK: yönetim paneli yerel testi geçti');
await db.close();
