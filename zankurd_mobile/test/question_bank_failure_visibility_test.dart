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

  // Codex denetimi 2026-10-29 (performans #1): kısmi hatada `_loaded` kalıcı
  // açılıyor, "Tekrar dene" aynı metodu çağırıp hemen dönüyordu. Bozuk dosya
  // → düzelme → tekrar deneme: yalnız başarısız paket yeniden okunur, hata
  // listesi temizlenir, sürüm sayacı değişir.
  test('bozuk paket düzelince tekrar deneme onu yükler', () async {
    const broken = 'assets/data/community_questions.json';
    var healthy = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final asset = const StringCodec().decodeMessage(message)!;
      final bytes = asset == broken && !healthy
          ? Uint8List.fromList('invalid json'.codeUnits)
          : await File(asset).readAsBytes();
      return ByteData.sublistView(bytes);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final loader = QuestionBankLoader.instance;
    final before = loader.revision.value;
    await loader.load();
    expect(loader.failedAssets, [broken]);

    healthy = true;
    await loader.load();
    expect(loader.failedAssets, isEmpty);
    expect(loader.allQuestions.any((q) => q.id.startsWith('comm_')), isTrue);
    expect(loader.revision.value, greaterThan(before));
  });
}
