import unittest

from prepare_room_limits import prepare


def snapshot():
    return {
        "function_definition": """CREATE OR REPLACE FUNCTION public.create_online_room_impl(
 p_category_ids text[], p_question_count integer, p_seconds_per_question integer,
 p_entry_fee integer, p_capacity integer, p_private boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
begin
 if p_seconds_per_question is null
   or p_seconds_per_question not in (10, 15, 20, 30, 45, 60) then
   raise exception 'duration'; end if;
 if p_question_count is null or p_question_count not in (5, 10, 15) then
   raise exception 'count'; end if;
 perform public.preserve_current_crowd_rewards_and_liveness();
 return '{}'::jsonb;
end;
$function$;
""",
        "constraints": [
            {"name": "rooms_question_count_check", "definition":
             "CHECK (((question_count >= 3) AND (question_count <= 30)))"},
            {"name": "rooms_seconds_per_question_check", "definition":
             "CHECK (((seconds_per_question >= 5) AND (seconds_per_question <= 60)))"},
        ],
    }


class RoomLimitsPreparationTest(unittest.TestCase):
    def test_changes_only_numeric_guards_and_preserves_current_body(self):
        original = snapshot()
        sql = prepare(original)
        self.assertIn('p_question_count not in (5, 10, 15, 20, 25, 30, 40, 50)', sql)
        self.assertIn('p_seconds_per_question not in (10, 15, 20, 30, 45, 60, 90, 120)', sql)
        self.assertIn('perform public.preserve_current_crowd_rewards_and_liveness();', sql)
        self.assertIn('question_count <= 50', sql)
        self.assertIn('seconds_per_question <= 120', sql)
        self.assertIn('question_count >= 3', sql)
        self.assertIn('seconds_per_question >= 5', sql)
        self.assertIn('pg_get_functiondef', sql)
        self.assertIn('source changed', sql)

    def test_rollback_verifies_expanded_body_and_keeps_incompatible_rooms(self):
        sql = prepare(snapshot(), rollback=True)
        self.assertIn('p_question_count not in (5, 10, 15)', sql)
        self.assertIn('p_seconds_per_question not in (10, 15, 20, 30, 45, 60)', sql)
        self.assertIn('question_count > 30 OR seconds_per_question > 60', sql)
        self.assertNotIn('delete from', sql.lower())
        self.assertIn('seconds_per_question <= 60', sql)
        self.assertIn('pg_get_constraintdef', sql)
        self.assertIn('select count(*) from pg_constraint', sql)

    def test_unknown_live_guard_is_rejected_instead_of_guessing(self):
        data = snapshot()
        data['function_definition'] = data['function_definition'].replace(
            '(5, 10, 15)', '(5, 10, 15, 25)')
        with self.assertRaisesRegex(ValueError, 'question guard'):
            prepare(data)

    def test_additional_constraint_predicate_is_not_silently_removed(self):
        data = snapshot()
        data['constraints'][0]['definition'] += ' AND question_count % 5 = 0'
        with self.assertRaisesRegex(ValueError, 'constraint'):
            prepare(data)

    def test_missing_constraint_rejected(self):
        data = snapshot()
        data['constraints'].pop()
        with self.assertRaisesRegex(ValueError, 'constraint'):
            prepare(data)


if __name__ == '__main__':
    unittest.main()
