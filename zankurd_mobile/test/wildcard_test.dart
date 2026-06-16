import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';

void main() {
  group('WildcardState', () {
    test('başlangıç — tüm flaglar false', () {
      const state = WildcardState();
      expect(state.fiftyFiftyUsed, isFalse);
      expect(state.audienceUsed, isFalse);
      expect(state.doubleAnswerActivated, isFalse);
      expect(state.changeQuestionUsed, isFalse);
    });

    test('isUsed — doğru flagı döner', () {
      const state = WildcardState(fiftyFiftyUsed: true);
      expect(state.isUsed(WildcardType.fiftyFifty), isTrue);
      expect(state.isUsed(WildcardType.audience), isFalse);
      expect(state.isUsed(WildcardType.doubleAnswer), isFalse);
      expect(state.isUsed(WildcardType.changeQuestion), isFalse);
    });

    test('copyWith — yalnızca belirtilen alanı günceller', () {
      const state = WildcardState(fiftyFiftyUsed: true);
      final updated = state.copyWith(audienceUsed: true);
      expect(updated.fiftyFiftyUsed, isTrue);
      expect(updated.audienceUsed, isTrue);
      expect(updated.doubleAnswerActivated, isFalse);
      expect(updated.changeQuestionUsed, isFalse);
    });

    test('resetForNextQuestion — tüm flagları temizler', () {
      const used = WildcardState(
        fiftyFiftyUsed: true,
        audienceUsed: true,
        doubleAnswerActivated: true,
        changeQuestionUsed: true,
      );
      final reset = used.resetForNextQuestion();
      expect(reset.fiftyFiftyUsed, isFalse);
      expect(reset.audienceUsed, isFalse);
      expect(reset.doubleAnswerActivated, isFalse);
      expect(reset.changeQuestionUsed, isFalse);
    });

    test('coin maliyetleri doğru', () {
      expect(WildcardType.fiftyFifty.coinCost, 20);
      expect(WildcardType.audience.coinCost, 30);
      expect(WildcardType.doubleAnswer.coinCost, 50);
      expect(WildcardType.changeQuestion.coinCost, 40);
    });

    test('tüm WildcardType değerlerine ikon ve etiket atanmış', () {
      for (final type in WildcardType.values) {
        expect(type.icon, isNotNull);
        expect(type.label(true), isNotEmpty);
        expect(type.label(false), isNotEmpty);
      }
    });
  });

  group('spendCoins — MockZanKurdRepository', () {
    late MockZanKurdRepository repo;

    setUp(() => repo = MockZanKurdRepository());

    test('bakiye yeterliyse true döner ve coin düşer', () async {
      final initial = await repo.loadCoinBalance();
      final success = await repo.spendCoins(100, 'test');
      expect(success, isTrue);
      expect(await repo.loadCoinBalance(), initial - 100);
    });

    test('bakiye yetersizse false döner, coin değişmez', () async {
      final initial = await repo.loadCoinBalance();
      final success = await repo.spendCoins(initial + 1, 'test');
      expect(success, isFalse);
      expect(await repo.loadCoinBalance(), initial);
    });

    test('tam bakiyeyi harcamak mümkün', () async {
      final balance = await repo.loadCoinBalance();
      final success = await repo.spendCoins(balance, 'all_in');
      expect(success, isTrue);
      expect(await repo.loadCoinBalance(), 0);
    });

    test('sıfır bakiyede harcama yapılamaz', () async {
      final balance = await repo.loadCoinBalance();
      await repo.spendCoins(balance, 'empty_balance');
      expect(await repo.spendCoins(1, 'after_empty'), isFalse);
    });

    test('ardışık harcamalar bakiyeyi doğru azaltır', () async {
      final initial = await repo.loadCoinBalance();
      await repo.spendCoins(20, 'fifty_fifty');
      await repo.spendCoins(30, 'audience');
      expect(await repo.loadCoinBalance(), initial - 50);
    });
  });
}
