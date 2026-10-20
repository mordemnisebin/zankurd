import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/question_prompt_parser.dart';

void main() {
  test('yönerge, cümle ve çeviri ayrılır', () {
    final p = parseQuestionPrompt(
      'Hevokê temam bike: "Ez ___ me." ("Ben öğretmenim.")',
    )!;
    expect(p.instruction, 'Hevokê temam bike');
    expect(p.main, 'Ez ___ me.');
    expect(p.hint, isNull);
    expect(p.translation, 'Ben öğretmenim.');
  });

  test('tırnak içi son parantez ipucu olur', () {
    final p = parseQuestionPrompt(
      'Hevokê temam bike: "Ev ___ e. (cihê jiyanê)" ("Bu evdir.")',
    )!;
    expect(p.main, 'Ev ___ e.');
    expect(p.hint, 'cihê jiyanê');
    expect(p.translation, 'Bu evdir.');
  });

  test('çevirinin içindeki tırnak bozmaz', () {
    final p = parseQuestionPrompt(
      'Cümleyi tamamla: "Şevê em dibêjin ___." '
      '("Geceleyin "iyi geceler" deriz.")',
    )!;
    expect(p.main, 'Şevê em dibêjin ___.');
    expect(p.translation, 'Geceleyin "iyi geceler" deriz.');
  });

  test('çevirisiz kelime sıralama metni', () {
    final p = parseQuestionPrompt('Hevokê rêz bike: "Ben öğretmenim."')!;
    expect(p.main, 'Ben öğretmenim.');
    expect(p.translation, isNull);
    expect(p.hint, isNull);
  });

  test('kalıba uymayan metin null döner', () {
    expect(parseQuestionPrompt('Paytexta Fransa kîjan e?'), isNull);
    expect(
      parseQuestionPrompt('Di hevoka "Ez ..." de binivîse: "Ez ___ dibînim."'),
      isNull,
    );
  });

  test('tamamı parantez olan cümle ipucuya bölünmez', () {
    final p = parseQuestionPrompt('Temam bike: "(Ez baş im.)"')!;
    expect(p.main, '(Ez baş im.)');
    expect(p.hint, isNull);
  });

  test('kaynak cümle cevap değilse Türkçe sayılır', () {
    expect(
      isTurkishSourceSentence('Ben öğretmenim.', ['Ez', 'mamoste', 'me']),
      isTrue,
    );
    expect(
      isTurkishSourceSentence('Ez mamoste me.', ['Ez', 'mamoste', 'me.']),
      isFalse,
    );
  });
}
