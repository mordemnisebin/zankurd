import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bozuk banka tanımlanır, sağlam içerik yüklenmeye devam eder', () async {
    const broken = 'assets/data/community_questions.json';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final asset = const StringCodec().decodeMessage(message)!;
      final bytes = asset == broken
          ? Uint8List.fromList('invalid json'.codeUnits)
          : await File(asset).readAsBytes();
      return ByteData.sublistView(bytes);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final loader = QuestionBankLoader.instance;
    await loader.load();
    expect(loader.failedAssets, [broken]);
    expect(loader.allQuestions.length, greaterThan(100));
    expect(loader.allQuestions.any((q) => q.id.startsWith('comm_')), isFalse);
  });
}
