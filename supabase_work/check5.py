import json, sys
sys.path.insert(0, '.')
from sb import query
print(query("SELECT language_code, question_type, option_c, option_d, correct_option, source_reference FROM public.questions WHERE source_url='zankurd_offline_curated_2026_07_12' LIMIT 5"))
print(query("SELECT question_type, count(*) FROM public.questions WHERE source_url='zankurd_offline_curated_2026_07_12' GROUP BY 1"))
