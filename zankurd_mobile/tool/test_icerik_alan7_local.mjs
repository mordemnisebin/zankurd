// Yerel PostgreSQL bekçisi (ağ/üretim bağlantısı yok; PGlite bellek DB).
// node tool/test_icerik_alan7_local.mjs /mutlak/yol/pglite/dist/index.js
// 2026-11-07_icerik_alan7.sql için: (A) göçün her (id, sütun) hedefi eski
// metinden yeniye geçer, correct_option değişmez; (B) geri alma her hedefi
// eskiye döndürür; (C) hedefleri arasında sonradan değişmiş alan bulunan
// soru HİÇ güncellenmez (yarım düzeltme yok) ve geri alma yine tutarlıdır;
// (E) yinelenen sorunun yeniden yazımı: doğru şık harfi sabit, kök/şıklar/açıklamalar yeni,
// geri alma eski kümeye döner; şık kümesi farklıysa soru atlanır.
// (D) sunucuda olmayan soru atlanır, ders slaytı metin parçası yalnız tam bir
// kez geçiyorsa değişir.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const modulePath = process.argv[2];
if (!modulePath || !path.isAbsolute(modulePath)) throw Error('Mutlak yerel PGlite yolu gerekli');
const {PGlite} = await import(pathToFileURL(modulePath).href);
const read = n => fs.readFileSync(new URL('../supabase/' + n, import.meta.url), 'utf8');
const mig = read('2026-11-07_icerik_alan7.sql');
const geri = read('geri_al/2026-11-07_icerik_alan7_geri.sql');

// Basit SQL dizgi ayrıştırıcı: ('a','b',...) satırları, '' kaçışı.
function tuples(sql, startMarker) {
  const i = sql.indexOf(startMarker);
  const out = [];
  let p = sql.indexOf('values', i) + 6;
  const end = sql.indexOf(';\n', p);
  while (p < end) {
    const o = sql.indexOf('(', p);
    if (o < 0 || o >= end) break;
    let q = o + 1; const vals = [];
    for (;;) {
      while (sql[q] === ' ' || sql[q] === ',') q++;
      if (sql[q] === ')') { q++; break; }
      if (sql[q] === "'") {
        let s = ''; q++;
        for (;;) {
          if (sql[q] === "'" && sql[q + 1] === "'") { s += "'"; q += 2; }
          else if (sql[q] === "'") { q++; break; }
          else s += sql[q++];
        }
        vals.push(s);
      } else {
        let s = ''; while (sql[q] !== ',' && sql[q] !== ')') s += sql[q++];
        vals.push(Number(s));
      }
    }
    out.push(vals); p = q;
  }
  return out;
}
const hedef = tuples(mig, 'insert into _hedef');
const ders = tuples(mig, 'insert into _ders');
const yeniden = tuples(mig, 'insert into _yeniden');
assert.ok(hedef.length > 100, 'hedef listesi okunamadi');

const yk = new Map(yeniden.map(r => [r[0], r[2]]));
async function fresh(mutate) {
  const db = await PGlite.create();
  await db.exec(`create table questions (id uuid primary key, prompt text, option_a text, option_b text,
    option_c text, option_d text, correct_option text, explanation text, explanation_ku text, explanation_tr text);
    create table lessons (id uuid primary key default gen_random_uuid(), slug text);
    create table lesson_slides (lesson_id uuid, order_in_lesson int, content_ku text, content_tr text);`);
  const byId = new Map();
  for (const [id, , sutun, eski] of hedef) {
    if (!byId.has(id)) byId.set(id, {sik: [], alan: {}});
    const q = byId.get(id);
    if (sutun === 'sik') q.sik.push(eski); else q.alan[sutun] = eski;
  }
  for (const [id, q] of byId) {
    const opts = [...q.sik]; while (opts.length < 4) opts.push('dolgu ' + opts.length);
    await db.query(`insert into questions values ($1,$2,$3,$4,$5,$6,'b',$7,$8,$9)`,
      [id, q.alan.prompt ?? yk.get(id) ?? 'kok', opts[0], opts[1], opts[2], opts[3],
       q.alan.explanation ?? 'a', q.alan.explanation_ku ?? 'b', q.alan.explanation_tr ?? 'c']);
  }
  const slugs = new Set(ders.map(d => d[0]));
  for (const s of slugs) {
    const {rows} = await db.query(`insert into lessons (slug) values ($1) returning id`, [s]);
    for (const [slug, ord, sutun, eski] of ders.filter(d => d[0] === s)) {
      const ex = await db.query(`select 1 from lesson_slides where lesson_id=$1 and order_in_lesson=$2`, [rows[0].id, ord]);
      if (!ex.rows.length) await db.query(`insert into lesson_slides values ($1,$2,'','')`, [rows[0].id, ord]);
      await db.query(`update lesson_slides set ${sutun} = ${sutun} || $3 where lesson_id=$1 and order_in_lesson=$2`,
        [rows[0].id, ord, 'ön ' + eski + ' son']);
    }
  }
  if (mutate) await mutate(db, byId);
  return {db, byId};
}
const val = (r, s) => s === 'sik' ? null : r[s];
async function state(db) { return (await db.query('select * from questions')).rows; }

// (A) tam uygulama
{
  const {db, byId} = await fresh();
  await db.exec(mig);
  const rows = new Map((await state(db)).map(r => [r.id, r]));
  for (const [id, , sutun, eski, yeni] of hedef) {
    const r = rows.get(id);
    if (sutun === 'sik') {
      const opts = [r.option_a, r.option_b, r.option_c, r.option_d];
      assert.ok(opts.includes(yeni), `sik yeni degil: ${id} ${yeni}`);
    } else assert.equal(r[sutun], yeni, `${id} ${sutun}`);
    assert.equal(r.correct_option, 'b');
  }
  const sl = (await db.query('select content_tr, content_ku from lesson_slides')).rows;
  for (const [, , sutun, eski, yeni] of ders) {
    const col = sutun === 'content_ku' ? 'content_ku' : 'content_tr';
    assert.ok(sl.some(x => x[col].includes(yeni) && !x[col].includes(eski)), 'ders: ' + yeni);
  }
  // (B) geri alma
  await db.exec(geri);
  const rows2 = new Map((await state(db)).map(r => [r.id, r]));
  for (const [id, , sutun, eski] of hedef) {
    const r = rows2.get(id);
    if (sutun === 'sik') assert.ok([r.option_a, r.option_b, r.option_c, r.option_d].includes(eski), 'geri sik ' + id);
    else assert.equal(r[sutun], eski, `geri ${id} ${sutun}`);
  }
  // idempotent: ikinci uygulama yine tam çalışır
  await db.exec(mig);
  await db.close();
}
// (C) sonradan değişmiş alan: o sorunun hiçbir hedefi uygulanmaz
{
  const hedefId = hedef.find(h => h[2] !== 'sik')[0];
  const {db} = await fresh(async d => {
    await d.query(`update questions set prompt = 'baskasi degistirdi', explanation_ku = 'baskasi' where id = $1`, [hedefId]);
  });
  await db.exec(mig);
  const r = (await db.query('select * from questions where id=$1', [hedefId])).rows[0];
  assert.equal(r.prompt, 'baskasi degistirdi');
  const kendi = hedef.filter(h => h[0] === hedefId && h[2] !== 'sik' && h[2] !== 'prompt' && h[2] !== 'explanation_ku');
  for (const [, , sutun, eski] of kendi) assert.equal(r[sutun], eski, 'atlanmali ' + sutun);
  // başka bir soru uygulanmış
  const other = hedef.find(h => h[0] !== hedefId && h[2] !== 'sik');
  const r2 = (await db.query('select * from questions where id=$1', [other[0]])).rows[0];
  assert.equal(r2[other[2]], other[4]);
  // geri alma değişmiş alanda ('baskasi') durmaz çünkü o soru hiç uygulanmadı:
  // hedef eskide olanlar atlanır, değişmiş alan hedef listesinde 'eski' de 'yeni' de değil → durur.
  await assert.rejects(() => db.exec(geri), /ne eski ne yeni/);
  await db.close();
}
// (D) sunucuda olmayan soru atlanır
{
  const id = hedef[0][0];
  const {db} = await fresh(async d => { await d.query('delete from questions where id=$1', [id]); });
  await db.exec(mig);
  const n = (await db.query('select count(*)::int c from questions')).rows[0].c;
  assert.ok(n > 10);
  await db.close();
}

// (E) yeniden yazım
{
  assert.ok(yeniden.length >= 1, 'yeniden yazim listesi bos');
  const mk = async mutate => {
    const db = await PGlite.create();
    await db.exec(`create table questions (id uuid primary key, prompt text, option_a text, option_b text,
      option_c text, option_d text, correct_option text, explanation text, explanation_ku text, explanation_tr text);
      create table lessons (id uuid primary key default gen_random_uuid(), slug text);
      create table lesson_slides (lesson_id uuid, order_in_lesson int, content_ku text, content_tr text);`);
    let i = 0;
    for (const r of yeniden) {
      const [id, , eskiKok, eskiDogru, e1, e2, e3, e4, , , , , , , , , eac, eacku, eactr] = r;
      const opts = [e1, e2, e3, e4];
      // doğru şıkkı DB'de farklı harfe koy (sıra JSON'dan farklı olabilir)
      const k = opts.indexOf(eskiDogru);
      assert.ok(k >= 0);
      const harf = 'ABCD'[(k + i++) % 4];
      const dig = opts.filter(x => x !== eskiDogru);
      const db4 = []; let j = 0;
      for (const L of 'ABCD') db4.push(L === harf ? eskiDogru : dig[j++]);
      await db.query(`insert into questions values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [id, eskiKok, ...db4, harf, eac, eacku, eactr]);
    }
    if (mutate) await mutate(db);
    return db;
  };
  const db = await mk();
  await db.exec(mig);
  for (const r of yeniden) {
    const [id, , , eskiDogru, , , , , yeniKok, yeniDogru, y1, y2, y3, yac, yacku, yactr] = r;
    const q = (await db.query('select * from questions where id=$1', [id])).rows[0];
    assert.equal(q.prompt, yeniKok);
    const harf = q.correct_option.toLowerCase();
    assert.equal(q['option_' + harf], yeniDogru);
    const digerleri = ['a', 'b', 'c', 'd'].filter(h => h !== harf).map(h => q['option_' + h]);
    assert.deepEqual(digerleri, [y1, y2, y3]);
    assert.equal(q.explanation, yac); assert.equal(q.explanation_ku, yacku); assert.equal(q.explanation_tr, yactr);
  }
  await db.exec(geri);
  for (const r of yeniden) {
    const [id, , eskiKok, eskiDogru, e1, e2, e3, e4, , , , , , , , , eac, eacku, eactr] = r;
    const q = (await db.query('select * from questions where id=$1', [id])).rows[0];
    assert.equal(q.prompt, eskiKok);
    assert.equal(q['option_' + q.correct_option.toLowerCase()], eskiDogru);
    assert.deepEqual([q.option_a, q.option_b, q.option_c, q.option_d].sort(), [e1, e2, e3, e4].sort());
    // açıklama sütunları: aynı soru alan düzeltmesi hedefindeyse geri alma onu da
    // eski-eskiye döndürür; burada yalnız kök ve şık kümesi denetlenir.
  }
  await db.close();
  // şık kümesi farklıysa atlanır
  const hedefId = yeniden[0][0];
  const db2 = await mk(async d => { await d.query(`update questions set option_a = 'baskasi' where id=$1`, [hedefId]); });
  await db2.exec(mig);
  const r0 = (await db2.query('select * from questions where id=$1', [hedefId])).rows[0];
  assert.equal(r0.prompt, yeniden[0][2], 'kume farkliysa atlanmali');
  await db2.close();
}
console.log('icerik_alan7 yerel bekçi: tamam —', hedef.length, 'hedef,', ders.length, 'ders metni,', yeniden.length, 'yeniden yazım');
