// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_yonetim_paneli_local.mjs /mutlak/yol/pglite/dist/index.js
//
// 2026-11-12_yonetim_paneli.sql için asıl sözleşme: YÖNETİCİ OLMAYAN HİÇBİR
// oturum hiçbir admin_* RPC'sini çalıştıramaz (42501). Sonra:
//  - anon/authenticated tablo yetkisi yok, anon'a EXECUTE yok, iç yardımcılar
//    kimseye açık değil, her admin_* SECURITY DEFINER + sabit search_path;
//  - yönetici akışları (onay/ret/düzelt/emekli/kapat, katkıcı ödülü, ilk 3
//    ödülü + ikinci ödülün reddi, ilk 3 dışına ödül yok, moderasyon, kendini/
//    yöneticiyi moderasyondan koruma, denetim günlüğü, bildirim tetikleyicisi);
//  - geri alma dosyası her şeyi kaldırır, ileri göç yeniden çalışır.
// Sınır: şema sade bir taklittir (canlı tablolar değil); coin_transactions
// kısıtları ve gerçek rol/RLS davranışı canlıda ayrıca doğrulanır.
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
  create table questions(id uuid primary key default gen_random_uuid(), category_id uuid, prompt text,
    option_a text, option_b text, option_c text, option_d text, correct_option text, explanation text,
    difficulty int, is_approved boolean default false, review_status text, created_by uuid,
    updated_at timestamptz default now());
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
  create table league_memberships(week_start date, player_id uuid, weekly_score bigint default 0);
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
  where n.nspname = 'public' and (p.proname like 'admin\\_%' or p.proname = '_admin_credit_coins')`);
assert(fns.length >= 20, 'admin işlevleri kurulmadı: ' + fns.length);
const internal = new Set(['admin_assert', 'admin_log', '_admin_credit_coins', 'admin_enqueue_push']);
for (const f of fns) {
  assert(f.prosecdef, `${f.sig} SECURITY DEFINER değil`);
  assert((f.proconfig || []).some(c => c.startsWith('search_path=')), `${f.sig} search_path sabit değil`);
  const anon = (await one(`select has_function_privilege('anon', $1::regprocedure, 'execute') v`, [f.sig])).v;
  const pub = (await one(`select has_function_privilege('public', $1::regprocedure, 'execute') v`, [f.sig])).v;
  const auth = (await one(`select has_function_privilege('authenticated', $1::regprocedure, 'execute') v`, [f.sig])).v;
  assert(!anon, `${f.sig} anon EXECUTE`);
  assert(!pub, `${f.sig} PUBLIC EXECUTE`);
  assert.equal(auth, !internal.has(f.proname), `${f.sig} authenticated yetkisi beklenenden farklı`);
}
for (const t of ['admins', 'admin_audit_log', 'admin_reward_grants', 'admin_contributor_rewards',
                 'user_moderation', 'admin_settings', 'admin_notify_prefs']) {
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
const covered = new Set(rpcs.map(r => r[0]).concat(['admin_is_admin', 'admin_assert', 'admin_log', '_admin_credit_coins', 'admin_enqueue_push']));
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
const stats = await call('public.admin_get_stats()');
assert.equal(stats.total_users, 8);
assert.equal(stats.crashes_week, null);

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

// Günün yarışması ödülü.
const day = '2026-11-12';
const contest = (await one(`insert into contests(day_key) values ($1) returning id`, [day])).id;
const ent = (u, sc) => q(`insert into contest_entries(contest_id, user_id, score, finished_at) values ($1, $2, $3, now())`, [contest, U(u), sc]);
await ent(WINNER, 980); await ent(SECOND, 910); await ent(THIRD, 860); await ent(OUTSIDER, 100);
const badge = (await one(`insert into contest_badges(slug) values ('gun-birincisi') returning id`)).id;
const cands = await call(`public.admin_list_reward_candidates('daily', '${day}')`);
assert.equal(cands.candidates.length, 3);
assert.deepEqual(cands.candidates.map(c => c.user_id), [U(WINNER), U(SECOND), U(THIRD)]);
assert.deepEqual(cands.suggested_coins, [500, 300, 100]);
const g1 = await call(`public.admin_grant_reward('daily', '${day}', '${U(WINNER)}', 500, 'gun-birincisi')`);
assert.equal(g1.granted, true); assert.equal(g1.rank, 1);
assert.equal((await one('select coins from profiles where id = $1', [U(WINNER)])).coins, 500);
assert.equal((await one('select count(*)::int n from user_contest_badges where user_id = $1', [U(WINNER)])).n, 1);
const g2 = await call(`public.admin_grant_reward('daily', '${day}', '${U(WINNER)}', 500, null)`);
assert.equal(g2.granted, false);
assert.equal((await one('select coins from profiles where id = $1', [U(WINNER)])).coins, 500, 'ikinci ödül jeton verdi');
await raises('ilk 3 dışı', '22023', `public.admin_grant_reward('daily', '${day}', '${U(OUTSIDER)}', 100, null)`);
await raises('hiçbir şey', '22023', `public.admin_grant_reward('daily', '${day}', '${U(SECOND)}', 0, null)`);
await raises('uçuk jeton', '22023', `public.admin_grant_reward('daily', '${day}', '${U(SECOND)}', 99999, null)`);
assert.equal((await call(`public.admin_list_reward_candidates('daily', '${day}')`)).candidates[0].rewarded, true);

// Haftalık: rozet yok; ilk 3 league_memberships'ten.
const wk = '2026-11-09';
for (const [u, sc] of [[SECOND, 5240], [WINNER, 4980], [THIRD, 4410], [OUTSIDER, 1]])
  await q('insert into league_memberships(week_start, player_id, weekly_score) values ($1, $2, $3)', [wk, U(u), sc]);
const wc = await call(`public.admin_list_reward_candidates('weekly', '${wk}')`);
assert.equal(wc.candidates[0].user_id, U(SECOND));
await raises('haftalık rozet', '22023', `public.admin_grant_reward('weekly', '${wk}', '${U(SECOND)}', 0, 'gun-birincisi')`);
assert.equal((await call(`public.admin_grant_reward('weekly', '${wk}', '${U(SECOND)}', 1000, null)`)).granted, true);
await raises('kötü tür', '22023', `public.admin_list_reward_candidates('monthly', null)`);

// Otomatik ödül ayarı.
assert.equal(await call('public.admin_get_auto_reward()'), true);
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
for (const a of audit) assert.equal(a.admin_id, U(ADMIN));
const actions = new Set(audit.map(a => a.action));
for (const a of ['suggestion_approve', 'suggestion_reject', 'question_fix', 'question_retire', 'question_dismiss',
                 'contributor_reward', 'reward_grant', 'auto_reward_set', 'user_suspend', 'user_lift'])
  assert(actions.has(a), 'denetim satırı yok: ' + a);
assert((await call('public.admin_list_audit(3)')).length === 3);

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

// ── 4. Geri alma ve yeniden ileri ────────────────────────────────────
await db.exec(rollback);
assert.equal((await one(`select count(*)::int n from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and (p.proname like 'admin\\_%' or p.proname = '_admin_credit_coins')`)).n, 0);
assert.equal((await one(`select count(*)::int n from pg_tables where schemaname = 'public'
  and tablename in ('admins','admin_audit_log','admin_reward_grants','admin_contributor_rewards','user_moderation','admin_settings','admin_notify_prefs')`)).n, 0);
assert.equal((await one(`select count(*)::int n from pg_trigger where tgname like 'trg_admin_push%'`)).n, 0);
assert.equal((await one(`select count(*)::int n from information_schema.columns where table_name = 'profile_reports' and column_name = 'handled_at'`)).n, 0);
// Geri alma asıl tablolara dokunmadı.
assert.equal((await one('select count(*)::int n from questions')).n, 4);
await db.exec(forward);
await db.query('insert into admins(user_id) values ($1)', [U(ADMIN)]);
await as(ADMIN);
assert.equal(await call('public.admin_is_admin()'), true);
await as(OTHER);
await denied('yeniden ileri: admin değil', 'public.admin_get_stats()');

console.log('OK: yönetim paneli yerel testi geçti');
await db.close();
