import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Denetim araçları, uygulamanın yüklediği bankaların TAMAMINI tarar.
///
/// ## Kusur
///
/// Banka listesi dört yerde ayrı ayrı yazılıydı ve zamanla ayrıştı:
///
///   * üretim yükleyicisi ................ 4 banka
///   * test yükleyicisi .................. 4 banka
///   * `audit_option_languages.dart` ..... 2 banka
///   * `audit_prompt_answer_language.dart` 1 banka
///   * `audit_explanation_language.dart` . 3 banka
///
/// `audit_option_languages.dart` tam da "şıklardan biri doğru cevabın
/// dilinde değil" kusurunu aramak için yazılmıştı ve `editorial_questions
/// .json`ı hiç açmıyordu — oysa uygulama o bankayı yüklüyor. Denetim
/// "temiz" diyordu çünkü baktığı yerde kusur yoktu. 305 editoryal ve 8
/// cümle kurma sorusu hiçbir dil denetiminden geçmemişti (2026-08-01).
///
/// ## Kural
///
/// Liste tek yerde durur (`questionBankAssets`); yükleyiciler ve araçlar
/// oradan okur. Bu bekçi, elle yazılmış bir yolun geri sızmadığını
/// doğrular — yeni bir banka eklendiğinde denetim kendiliğinden kapsasın.
void main() {
  test('paylaşılan liste uygulamanın yüklediği bankaları içeriyor', () {
    expect(questionBankAssets, isNotEmpty);
    for (final asset in questionBankAssets) {
      expect(
        File(asset).existsSync(),
        isTrue,
        reason: '$asset listede var ama dosya yok.',
      );
    }
    // pubspec bunları paket içine almalı, yoksa uygulama boş banka yükler.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('assets/data/'),
      reason: 'Bankalar pakete girmezse liste anlamsız.',
    );
  });

  test('yükleyiciler ve araçlar elle yol yazmıyor', () {
    // Kusurun kendisi buydu: her dosya kendi listesini tutuyordu.
    const mustUseSharedList = [
      'lib/src/data/question_bank_loader.dart',
      'lib/src/data/question_bank_loader_io.dart',
      'tool/audit_option_languages.dart',
      'tool/audit_prompt_answer_language.dart',
      'tool/audit_explanation_language.dart',
    ];
    final offenders = <String>[];
    for (final path in mustUseSharedList) {
      final source = File(path).readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      if (!code.contains('questionBankAssets')) {
        offenders.add('$path: paylaşılan listeyi kullanmıyor');
        continue;
      }
      // Elle yazılmış bir banka yolu kalmışsa liste yine ayrışır.
      final hardcoded = RegExp(
        r"'assets/data/[a-z_]*questions\.json'",
      ).allMatches(code).map((m) => m.group(0)!).toSet();
      if (hardcoded.isNotEmpty) {
        offenders.add('$path: elle yazılmış yol ${hardcoded.join(", ")}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosya(lar) kendi banka listesini tutuyor; denetim ile '
          'uygulamanın gördüğü bankalar yeniden ayrışır:\n'
          '${offenders.join("\n")}',
    );
  });
}
