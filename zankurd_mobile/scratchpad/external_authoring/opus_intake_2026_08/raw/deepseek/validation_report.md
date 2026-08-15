# Validation Report — deepseek wave 01

Date: 2026-08-06
Author: deepseek-v4-flash-free-independent-author
Branch: content/author-deepseek-wave-01-2026-08-06
Worktree: /Users/kocer/Projects/zankurd-worktrees/content-author-deepseek-2026-08-06
HEAD base: 0602b8d

## Per-batch gate results

### batch_01 (Sînema)
```
input rows       : 125
accepted         : 125
rejected         : 0
position         : {0: 24.8, 1: 25.6, 2: 24.8, 3: 24.8}
longest_same_position_run: 1
longest_option_is_correct_pct: 33.6
difficulty       : {1: 11.2, 2: 35.2, 3: 32.0, 4: 21.6}
near_duplicate_pct: 0.0
top_prompt_template_pct: 4.0
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

### batch_02 (Edebiyat)
```
input rows       : 125
accepted         : 125
rejected         : 0
position         : {0: 24.8, 1: 25.6, 2: 24.8, 3: 24.8}
longest_same_position_run: 1
longest_option_is_correct_pct: 30.4
difficulty       : {1: 3.2, 2: 33.6, 3: 40.8, 4: 22.4}
near_duplicate_pct: 0.0
top_prompt_template_pct: 3.2
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

### batch_03 (Çand û Muzîk)
```
input rows       : 125
accepted         : 125
rejected         : 0
position         : {0: 24.8, 1: 25.6, 2: 24.8, 3: 24.8}
longest_same_position_run: 1
longest_option_is_correct_pct: 18.4
difficulty       : {1: 13.6, 2: 42.4, 3: 31.2, 4: 12.8}
near_duplicate_pct: 0.0
top_prompt_template_pct: 3.2
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

### batch_04 (Cografya)
```
input rows       : 125
accepted         : 125
rejected         : 0
position         : {0: 24.8, 1: 25.6, 2: 24.8, 3: 24.8}
longest_same_position_run: 1
longest_option_is_correct_pct: 20.0
difficulty       : {1: 20.0, 2: 42.4, 3: 26.4, 4: 11.2}
near_duplicate_pct: 0.0
top_prompt_template_pct: 2.4
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

## Summary totals
- produced attempt: 500
- accepted: 500
- rejected/quarantine records: 0 (all batches final-run clean)
- category distribution: {'Sînema': 125, 'Edebiyat': 125, 'Çand/Muzîk': 125, 'Cografya': 125}
- subcategories (Cografya): Çiya û Çem, Bajar û Cî, Sînor û Awa (matches subcategory_config.dart)
- TR/KU coverage: KU prompts 500/500, TR prompts 500/500 (100% bilingual)
- source verification: textbook-stable-fact + honest provenance (no fabricated URLs)
- duplicate/bias: all batches PASS validate_batch.py distribution gates; zero near-duplicates vs 2005-prompt existing index
- commits:
  - d74747b content(candidate-deepseek): author cinema batch
  - 741aa0e content(candidate-deepseek): author literature batch
  - e563656 content(candidate-deepseek): author culture and music batch
  - a674050 content(candidate-deepseek): author geography batch
- files:
  - scratchpad/external_authoring/deepseek_wave_01/batch_0[1-4]_provenance.json
  - scratchpad/external_authoring/deepseek_wave_01/batch_0[1-4]_questions.json
  - scratchpad/external_authoring/deepseek_wave_01/batch_0[1-4]_questions.json.accepted.json
  - scratchpad/external_authoring/deepseek_wave_01/batch_0[1-4]_questions.json.quarantine.json
  - scratchpad/external_authoring/deepseek_wave_01/batch_0[1-4]_questions.json.report.json
  - scratchpad/external_authoring/deepseek_wave_01/batch_0[1-4]_src.json
  - scratchpad/external_authoring/deepseek_wave_01/tools/src_batch0[1-4]_p[1-3].py
  - scratchpad/external_authoring/deepseek_wave_01/validation_report.md
  - scratchpad/external_authoring/deepseek_wave_01/tools/apply_batch03_fixes.py

## Runtime/production
- Main/runtime/production: NOT touched
- question_bank_assets.dart: NOT touched
- source_manifest.json: NOT touched
- quality baseline: NOT changed
