import 'package:flutter_test/flutter_test.dart';

import 'support/active_sql.dart';

void main() {
  test('yorumlanmış REVOKE etkin SQL sayılmaz', () {
    const sql = '''
-- revoke select on public.profiles from anon;
/* revoke all on table public.profiles
   from anon; */
REVOKE   SELECT ON public.profiles FROM public;
''';
    final active = activeSql(sql);
    expect(active, isNot(contains('from anon')));
    expect(active, contains('revoke select on public.profiles from public;'));
  });
}
