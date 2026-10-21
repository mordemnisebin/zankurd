import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

void main() {
  test('günlük tur dersle karışmaz ve giriş ile başlık aynı adı kullanır', () {
    for (final language in AppLanguage.values) {
      final expected = language == AppLanguage.ku ? 'Gera rojê' : 'Günün turu';
      expect(Tr.of(K.dailyContest, language), expected);
      expect(Tr.of(K.dailyEvent, language), expected);
      expect(Tr.of(K.dailyLesson, language), isNot(expected));
      expect(Tr.of(K.gununDersi, language), Tr.of(K.dailyLesson, language));
      for (final key in [
        K.contestStartFailed,
        K.contestLoadFailed,
        K.contestNoneToday,
        K.howToPlayBody,
      ]) {
        expect(Tr.of(key, language), contains(expected));
      }
    }
  });
}
