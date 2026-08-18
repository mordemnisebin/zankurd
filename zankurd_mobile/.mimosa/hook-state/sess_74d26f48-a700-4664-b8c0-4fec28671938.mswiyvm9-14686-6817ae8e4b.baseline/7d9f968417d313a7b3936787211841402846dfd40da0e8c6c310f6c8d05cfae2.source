#!/usr/bin/env python3
"""
exact_duplicates.csv dosyasini okuyarak tekillestirme SQL migrasyonu üretür.
Cikti: ../../supabase/2026-07-22_deduplicate_questions.sql
"""

import csv
import os
from collections import defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(SCRIPT_DIR, 'reports', 'exact_duplicates.csv')
OUT_PATH = os.path.join(SCRIPT_DIR, '..', 'supabase',
                        '2026-07-22_deduplicate_questions.sql')

# ── 1. CSV oku ─────────────────────────────────────────────────────
clusters: dict[str, list[dict]] = defaultdict(list)

with open(CSV_PATH, newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        fp = row['issue_fingerprint']
        clusters[fp].append(row)

# ── 2. Küme istatistikleri ─────────────────────────────────────────
total_clusters = len(clusters)
total_questions = sum(len(v) for v in clusters.values())
total_to_disable = sum(len(v) - 1 for v in clusters.values())
total_to_keep = total_clusters  # küme basina 1 temsilci

# Sadece birden fazla üyesi olan kümeler (gerçek tekrarlar)
multi_clusters = {fp: rows for fp, rows in clusters.items() if len(rows) > 1}
real_to_disable = sum(len(v) - 1 for v in multi_clusters.values())

print(f'Toplam fingerprint:       {total_clusters}')
print(f'Toplam soru kaydi:        {total_questions}')
print(f'Tekrarli kümeler:         {len(multi_clusters)}')
print(f'Devre disi birakilacak:   {real_to_disable}')
print(f'Korunacak temsilci:       {len(multi_clusters)}')

# ── 3. Devre disi birakilacak prompt'lari topla ────────────────────
# Her küme icin ilk kayit (en düsük record_id) = temsilci
# Diger kayitlarin prompt'lari devre disi birakilacak.

disable_prompts: list[str] = []
keep_prompts: list[str] = []

for fp, rows in sorted(multi_clusters.items()):
    # record_id'ye göre sirala — en düsük ID = temsilci
    rows_sorted = sorted(rows, key=lambda r: r['record_id'])
    keep = rows_sorted[0]
    keep_prompts.append(keep['prompt'])
    for dup in rows_sorted[1:]:
        disable_prompts.append(dup['prompt'])

# Tekrarlanan prompt'lari kaldir — SQL IN clause icin essiz liste
disable_prompts = sorted(set(disable_prompts), key=len)
keep_prompts_unique = sorted(set(keep_prompts), key=len)

print(f'Essiz devre disi prompt:  {len(disable_prompts)}')

# Prompt'larin SQL-safe escaped versiyonlari
def sql_escape(s: str) -> str:
    return s.replace("'", "''")

# ── 4. SQL üret ────────────────────────────────────────────────────
lines: list[str] = []

lines.append('-- ============================================================')
lines.append('-- ZanKurd: Tekrar soru temizligi (deduplication) migrasyonu')
lines.append('-- Tarih: 2026-07-22')
lines.append('-- Kaynak: tools/reports/exact_duplicates.csv')
lines.append('-- ============================================================')
lines.append('--')
lines.append(f'-- Toplam tekrar kümesi:          {len(multi_clusters)}')
lines.append(f'-- Devre disi birakilacak soru:    {real_to_disable}')
lines.append(f'-- Korunacak temsilci soru:        {len(multi_clusters)}')
lines.append(f'-- (Tek üyeli kümeler dahil degil — onlar zaten essiz.)')
lines.append('--')
lines.append('-- Yöntem:')
lines.append('--   - Her küme icin 1 temsilci korunur (en düsük offline ID).')
lines.append('--   - Diger küme üyeleri prompt eslesmesiyle bulunur ve')
lines.append('--     is_approved=false, review_status=''rejected'' yapilir.')
lines.append('--   - Sorular SILINMEZ, sadece devre disi birakilir.')
lines.append('-- ============================================================')
lines.append('')

# ── 4a. DRY-RUN SELECT ────────────────────────────────────────────
lines.append('-- ============================================================')
lines.append('-- BOLUM 1: DRY-RUN — Etkilenecek sorulari göster (calistirma)')
lines.append('-- ============================================================')
lines.append('')

# Devre disi birakilacak prompt listesi — IN clause ile
# Cok uzun oldugu icin alt kümelere bölelim
CHUNK = 50
prompt_chunks = [disable_prompts[i:i+CHUNK] for i in range(0, len(disable_prompts), CHUNK)]

lines.append('-- Asagidaki SELECT sorgusu hangi sorularin etkilenecegini gösterir.')
lines.append('-- Sonuc kumesini incele, beklenen sayilarla eslesiyorsa Bolum 2 yi calistir.')
lines.append('')

# Tek büyük SELECT — IN clause ile
lines.append('SELECT q.id, q.prompt, q.difficulty, q.question_type,')
lines.append('       q.is_approved, q.review_status, q.source_url')
lines.append('FROM public.questions q')
lines.append('WHERE q.is_approved = true')
lines.append('  AND lower(trim(q.prompt)) IN (')

for i, chunk in enumerate(prompt_chunks):
    escaped = [f"    lower(trim(E'{sql_escape(p)}'))" for p in chunk]
    joined = ',\n'.join(escaped)
    if i < len(prompt_chunks) - 1:
        lines.append(joined + ',')
    else:
        lines.append(joined)

lines.append('  )')
lines.append('ORDER BY q.prompt, q.created_at;')
lines.append('')

# ── 4b. UPDATE — Tekillestirme ────────────────────────────────────
lines.append('-- ============================================================')
lines.append('-- BOLUM 2: UPDATE — Tekrar sorulari devre disi birak')
lines.append('-- ============================================================')
lines.append('')
lines.append('BEGIN;')
lines.append('-- Hata olursa asagidaki satirin yorumunu kaldir ve calistir:')
lines.append('-- ROLLBACK;')
lines.append('')

lines.append(f'-- {real_to_disable} soru devre disi birakilacak.')
lines.append(f'-- {len(multi_clusters)} temsilci korunacak.')
lines.append('')

lines.append('UPDATE public.questions')
lines.append("SET is_approved = false,")
lines.append("    review_status = 'rejected',")
lines.append("    reviewed_by = 'dedup_migration',")
lines.append("    reviewed_at = NOW()")
lines.append('WHERE is_approved = true')
lines.append('  AND lower(trim(prompt)) IN (')

for i, chunk in enumerate(prompt_chunks):
    escaped = [f"    lower(trim(E'{sql_escape(p)}'))" for p in chunk]
    joined = ',\n'.join(escaped)
    if i < len(prompt_chunks) - 1:
        lines.append(joined + ',')
    else:
        lines.append(joined)

lines.append('  )')
# Her kümeden birini koru — en eski created_at, yoksa en düsük id
lines.append('  AND id NOT IN (')
lines.append('    -- Her tekrar kümesinden 1 temsilci korunur')
lines.append('    SELECT DISTINCT ON (lower(trim(prompt))) id')
lines.append('    FROM public.questions')
lines.append('    WHERE is_approved = true')
lines.append('    ORDER BY lower(trim(prompt)),')
lines.append('             COALESCE(quality_version, 0) DESC,')
lines.append('             created_at ASC,')
lines.append('             id ASC')
lines.append('  );')
lines.append('')

# ── 4c. Dogrulama ─────────────────────────────────────────────────
lines.append('-- ============================================================')
lines.append('-- BOLUM 3: DOGRULAMA — Etki raporu')
lines.append('-- ============================================================')
lines.append('')
lines.append('SELECT')
lines.append("  count(*) AS toplam_soru,")
lines.append("  count(*) FILTER (WHERE is_approved = true) AS onayli_soru,")
lines.append("  count(*) FILTER (WHERE is_approved = false) AS devre_disi_soru,")
lines.append("  count(*) FILTER (WHERE reviewed_by = 'dedup_migration') AS bu_migrasyon_etkilenen")
lines.append('FROM public.questions;')
lines.append('')
lines.append('COMMIT;')
lines.append('')

# ── 5. Dosya yaz ──────────────────────────────────────────────────
sql_content = '\n'.join(lines) + '\n'
with open(OUT_PATH, 'w', encoding='utf-8') as fh:
    fh.write(sql_content)

print(f'\nSQL dosyasi yazildi: {OUT_PATH}')
print(f'Dosya boyutu: {len(sql_content):,} bayt, {len(lines)} satir')
