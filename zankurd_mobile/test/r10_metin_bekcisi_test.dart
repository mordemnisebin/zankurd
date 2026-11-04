// R10 metin denetimi bekçileri (GPT-6 Pro alan 6).
//
// Her sınama, denetimde kanıtlanmış bir kusurun geri gelmesini yakalar:
//  * tekil sayıda çoğul Kurmancî biçimi ("1 peyvên tomarkirî"),
//  * gizlilik metninin gerçek veri akışıyla çelişmesi,
//  * ders açıklamasında yön başına sabit "e/ye" kopulası,
//  * günlük görev ödülünün FAQ'de yanlış anlatılması.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learning_assessment_bank.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

void main() {
  String ku(String key, Map<String, String> p) => Tr.of(key, AppLanguage.ku, p);
  String tr(String key, Map<String, String> p) => Tr.of(key, AppLanguage.tr, p);

  group('Kurmancî tekil/çoğul', () {
    test('1 için tekil biçim, öbür sayılar için çoğul', () {
      expect(ku(K.wordsSavedCount, {'count': '1'}), 'Peyveke tomarkirî');
      expect(ku(K.wordsSavedCount, {'count': '2'}), '2 peyvên tomarkirî');
      expect(ku(K.timerSecondsLeft, {'n': '1'}), '1 çirke maye');
      expect(ku(K.timerSecondsLeft, {'n': '2'}), '2 çirke mane');
      expect(
        ku(K.progressLevelsCompleted, {'completed': '1', 'total': '5'}),
        '1 ji 5 astan temam bû',
      );
      expect(ku(K.pSenkronizeEdilemedi, {'p0': '1'}), contains('nehat şandin'));
      expect(ku(K.pendingOnDeviceP, {'p0': '1'}), '1 tomar li amûrê ye');
      expect(ku(K.pendingOnDeviceP, {'p0': '3'}), '3 tomar li amûrê ne');
      expect(ku(K.pDogruCevap, {'p0': '1'}), 'Bersiveke rast');
      expect(ku(K.crowdWaitingCount, {'n': '1'}), 'Li benda lîstikvanekî…');
      expect(ku(K.wheelExtraSpins, {'n': '1'}), '+ zivirandineke zêde');
      expect(ku(K.roomInviteSent, {'n': '1'}), 'Vexwendin ji hevalekî re çû');
      expect(
        ku(K.roomPlayersNotReady, {'n': '1'}),
        'Divê lîstikvanekî din jî amade bibe.',
      );
    });

    test('Türkçe tekil biçimden etkilenmez', () {
      expect(tr(K.wordsSavedCount, {'count': '1'}), 'Kayıtlı 1 kelime');
    });
  });

  test('gizlilik metni kayıtlı hesabın gerçek veri akışını söyler', () {
    final trBody = Tr.of(K.privacyBody, AppLanguage.tr);
    final kuBody = Tr.of(K.privacyBody, AppLanguage.ku);
    expect(trBody, isNot(contains('Çıkış yaptığında cihazdaki ilerleme')));
    expect(trBody, contains('kelime listen ve öğrenme hedefin'));
    expect(kuBody, contains('armanca hînbûnê'));
    expect(kuBody, isNot(contains('hemû daneyên xwe yên serhêl')));
  });

  test('FAQ günlük görevlerin jeton değil XP verdiğini söyler', () {
    expect(
      Tr.of(K.faqCoinsA, AppLanguage.tr),
      contains('günlük görevler XP verir'),
    );
  });

  test('ders açıklamasında kopula son harfe göre seçilir', () {
    expect(LearningAssessmentBank.copulaFor('Erkek kardeş'), 'e');
    expect(LearningAssessmentBank.copulaFor('Bira'), 'ye');
    expect(LearningAssessmentBank.copulaFor('Dest'), 'e');
    expect(LearningAssessmentBank.copulaFor('Kedi'), 'ye');
    expect(LearningAssessmentBank.copulaFor('Ew û'), 'ye');
  });
}
