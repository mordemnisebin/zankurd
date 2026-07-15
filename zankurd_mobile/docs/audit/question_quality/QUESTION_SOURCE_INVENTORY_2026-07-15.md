# Question Source Inventory — 2026-07-15

Physical records count every parsed or counted source row; parsed records are records mapped to the canonical audit model.

| Source | Role | Parser | Physical | Parsed | Gate | Production-like | Errors |
|---|---|---:|---:|---:|---:|---:|---:|
| `active_import_ready` | `import_candidate` | `csv` | 10000 | 10000 | true | true | 0 |
| `curated_runtime_bank` | `runtime_secondary` | `dart_quiz_question` | 20 | 20 | true | true | 0 |
| `editorial_wave2_review` | `candidate_pool` | `csv` | 10000 | 10000 | false | false | 0 |
| `generated_master_csv` | `historical_snapshot` | `csv` | 285 | 285 | false | false | 0 |
| `historical_question_sql` | `historical_snapshot` | `sql_count` | 8 | 0 | false | false | 0 |
| `historical_question_sql` | `historical_snapshot` | `sql_count` | 10000 | 0 | false | false | 0 |
| `historical_question_sql` | `historical_snapshot` | `sql_count` | 10000 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 6 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 125 | 0 | false | false | 0 |
| `historical_rich_parts` | `historical_snapshot` | `sql_count` | 112 | 0 | false | false | 0 |
| `historical_rich_sql` | `historical_snapshot` | `sql_count` | 36 | 0 | false | false | 0 |
| `historical_rich_sql` | `historical_snapshot` | `sql_count` | 10008 | 0 | false | false | 0 |
| `historical_sql_chunks` | `historical_snapshot` | `sql_count` | 2000 | 0 | false | false | 0 |
| `historical_sql_chunks` | `historical_snapshot` | `sql_count` | 2000 | 0 | false | false | 0 |
| `historical_sql_chunks` | `historical_snapshot` | `sql_count` | 2000 | 0 | false | false | 0 |
| `historical_sql_chunks` | `historical_snapshot` | `sql_count` | 2000 | 0 | false | false | 0 |
| `historical_sql_chunks` | `historical_snapshot` | `sql_count` | 2008 | 0 | false | false | 0 |
| `live_kurmanci_export` | `runtime_secondary` | `csv` | 377 | 377 | true | true | 0 |
| `offline_runtime_bank` | `runtime_primary` | `dart_quiz_question` | 3125 | 3125 | true | true | 0 |
| `open_web_master` | `candidate_pool` | `csv` | 2444 | 2444 | false | false | 0 |
| `open_web_review_queue` | `candidate_pool` | `csv` | 2444 | 2444 | false | false | 0 |
| `opentdb_candidate_pool` | `candidate_pool` | `csv` | 300 | 300 | false | false | 0 |
| `opentdb_remaining` | `candidate_pool` | `csv` | 825 | 825 | false | false | 0 |
| `pure_kurdish_pilot` | `candidate_pool` | `json` | 80 | 80 | false | false | 0 |
| `rich_v2_csv_snapshot` | `historical_snapshot` | `csv` | 10000 | 10000 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 23 | 23 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 12 | 12 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 10 | 10 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 10 | 10 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 24 | 24 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 24 | 24 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 24 | 24 | false | false | 0 |
| `translated_batches` | `candidate_pool` | `csv` | 12 | 12 | false | false | 0 |
| `wave2_publish_candidates` | `publish_candidate` | `csv` | 49 | 49 | true | true | 0 |
| `wave2_publish_sql_snapshot` | `historical_snapshot` | `sql_count` | 49 | 0 | false | false | 0 |
| `wave2_quarantine` | `quarantine` | `csv` | 9951 | 9951 | false | false | 0 |
| `wave2_reviewed` | `historical_snapshot` | `csv` | 10000 | 10000 | false | false | 0 |
| `wikidata_candidates` | `candidate_pool` | `csv` | 1319 | 1319 | false | false | 0 |

Unknown sources: 0.
Missing production-like sources: 0.
