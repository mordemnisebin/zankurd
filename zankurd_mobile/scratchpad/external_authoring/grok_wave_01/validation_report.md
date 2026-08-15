# Validation Report — grok wave 01

Date: 2026-08-06
Author: grok-4.5-independent-author
Branch: content/author-grok-wave-01-2026-08-06
Worktree: /Users/kocer/Projects/zankurd-worktrees/content-author-grok-2026-08-06
HEAD base: be98dc3

## Per-batch gate results

### batch_01
```
batch            : /Users/kocer/Projects/zankurd-worktrees/content-author-grok-2026-08-06/zankurd_mobile/scratchpad/external_authoring/grok_wave_01/batch_01_questions.json
input rows       : 125
accepted         : 125
rejected         : 0
position         : {0: 24.8, 1: 25.6, 2: 24.8, 3: 24.8}
longest_same_position_run: 1
longest_option_is_correct_pct: 34.4
difficulty       : {1: 28.8, 2: 51.2, 3: 20.0}
near_duplicate_pct: 0.0
top_prompt_template_pct: 0.8
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

### batch_02
```
batch            : /Users/kocer/Projects/zankurd-worktrees/content-author-grok-2026-08-06/zankurd_mobile/scratchpad/external_authoring/grok_wave_01/batch_02_questions.json
input rows       : 100
accepted         : 100
rejected         : 0
position         : {0: 27.0, 1: 27.0, 2: 22.0, 3: 24.0}
longest_same_position_run: 2
longest_option_is_correct_pct: 33.0
difficulty       : {2: 24.0, 3: 51.0, 4: 25.0}
near_duplicate_pct: 0.0
top_prompt_template_pct: 7.0
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

### batch_03
```
batch            : /Users/kocer/Projects/zankurd-worktrees/content-author-grok-2026-08-06/zankurd_mobile/scratchpad/external_authoring/grok_wave_01/batch_03_questions.json
input rows       : 91
accepted         : 91
rejected         : 0
position         : {0: 24.2, 1: 26.4, 2: 24.2, 3: 25.3}
longest_same_position_run: 2
longest_option_is_correct_pct: 30.8
difficulty       : {1: 16.5, 2: 46.2, 3: 29.7, 4: 7.7}
near_duplicate_pct: 0.0
top_prompt_template_pct: 1.1
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

### batch_04
```
batch            : /Users/kocer/Projects/zankurd-worktrees/content-author-grok-2026-08-06/zankurd_mobile/scratchpad/external_authoring/grok_wave_01/batch_04_questions.json
input rows       : 91
accepted         : 91
rejected         : 0
position         : {0: 24.2, 1: 25.3, 2: 24.2, 3: 26.4}
longest_same_position_run: 2
longest_option_is_correct_pct: 35.2
difficulty       : {1: 17.6, 2: 52.7, 3: 22.0, 4: 7.7}
near_duplicate_pct: 0.0
top_prompt_template_pct: 2.2
distribution gates: {'position_ok': True, 'run_ok': True, 'length_bias_ok': True, 'near_duplicate_ok': True, 'template_ok': True}
RESULT: PASS
```

## Summary totals
- produced attempt: 500
- accepted: 407
- rejected/quarantine records: 93
- category distribution: {'Teknolojî': 225, 'Cografya': 91, 'Dîrok': 91}
- TR/KU coverage: KU prompts 407/407, TR prompts 407/407 (100% bilingual)
- source verification: textbook-stable-fact + honest provenance (no fabricated URLs)
- duplicate/bias: all batches PASS validate_batch.py distribution gates
- files:
  - scratchpad/external_authoring/grok_wave_01/batch_01_provenance.json
  - scratchpad/external_authoring/grok_wave_01/batch_01_questions.json
  - scratchpad/external_authoring/grok_wave_01/batch_02_provenance.json
  - scratchpad/external_authoring/grok_wave_01/batch_02_questions.json
  - scratchpad/external_authoring/grok_wave_01/batch_03_provenance.json
  - scratchpad/external_authoring/grok_wave_01/batch_03_questions.json
  - scratchpad/external_authoring/grok_wave_01/batch_04_provenance.json
  - scratchpad/external_authoring/grok_wave_01/batch_04_questions.json
  - scratchpad/external_authoring/grok_wave_01/validation_report.md
  - scratchpad/external_authoring/grok_wave_01/rejected_questions.json

## Runtime/production
- Main/runtime/production: NOT touched
- question_bank_assets.dart: NOT touched
- source_manifest.json: NOT touched
- quality baseline: NOT changed
