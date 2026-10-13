import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/referral_result.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'offline repository sahte uzak kimlik veya yazma başarısı üretmez',
    () async {
      final repository = OfflineZanKurdRepository();

      expect(repository.currentUserId, isNull);
      expect(await repository.getPlayerTag(), isNull);
      expect(await repository.addFriend('u2', 'Rojda'), isFalse);
      expect(await repository.acceptFriendRequest('r1'), isFalse);
      expect(await repository.rejectFriendRequest('r1'), isFalse);
      expect(
        await repository.reportRoomMessage(messageId: 'm1', reason: 'spam'),
        isFalse,
      );
      expect(
        await repository.reportPlayerProfile(
          playerId: 'u2',
          reason: 'uygunsuz',
        ),
        isFalse,
      );
      expect(
        await repository.submitSuggestedQuestion(
          category: 'Ziman',
          prompt: 'Pirs?',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          optionD: 'D',
          correctOption: 'A',
        ),
        isFalse,
      );
      expect(
        await repository.saveTournamentProgress('semi', 10, 8, const ['bot']),
        isFalse,
      );
    },
  );

  test('offline oyuncu adı cihazda kalıcıdır', () async {
    final first = OfflineZanKurdRepository();
    await first.updateProfileName('Rojda');

    final second = OfflineZanKurdRepository();
    expect(await second.getProfileName(), 'Rojda');
  });

  test('offline sunucu yazımları mock başarıya düşmez', () async {
    final repository = OfflineZanKurdRepository();

    await expectLater(repository.deleteMyAccount(), throwsStateError);
    await expectLater(
      repository.sendRoomMessage(roomId: 'room-offline', text: 'Silav'),
      throwsStateError,
    );
    expect(await repository.blockPlayer('u2'), isFalse);
    expect(await repository.unblockPlayer('u2'), isFalse);
  });

  test('offline oda yetki yazımları mock no-op başarısına düşmez', () async {
    final repository = OfflineZanKurdRepository();
    final room = repository.createRoom();

    await expectLater(repository.acknowledgeRoomResult(room), throwsStateError);
    await expectLater(repository.markRoomClientReady(room), throwsStateError);
    await expectLater(
      repository.advanceRoomQuestion(room, expectedQuestionIndex: 0),
      throwsStateError,
    );
    await expectLater(repository.leaveOnlineRoom(room), throwsStateError);
    await expectLater(repository.updateReady(room, true), throwsStateError);
    await expectLater(repository.startGame(room), throwsStateError);
    await expectLater(repository.finishGame(room), throwsStateError);
    await expectLater(
      repository.sendRoomBroadcast('offline-room', const {'type': 'ready'}),
      throwsStateError,
    );
  });

  test('offline oda sunucu durumu veya cevap RPCsi taklit etmez', () async {
    final repository = OfflineZanKurdRepository();
    final room = repository.createRoom();
    final question = repository.playableQuestions.first;

    await expectLater(repository.loadRoomPlayers(room), throwsStateError);
    await expectLater(repository.loadRoomStatus(room), throwsStateError);
    await expectLater(repository.loadRoomEndState(room), throwsStateError);
    await expectLater(
      repository.submitAnswer(
        room: room,
        question: question,
        selectedOptionOptionKey: 'A',
        responseMs: 800,
      ),
      throwsStateError,
    );
  });

  test('offline FCM tokenı sunucuya yazılmış gibi davranmaz', () async {
    final repository = OfflineZanKurdRepository();

    await expectLater(
      repository.setFcmToken('offline-token'),
      throwsStateError,
    );
  });

  test('offline avatar fotoğrafı uzaktan silinmiş gibi davranmaz', () async {
    final repository = OfflineZanKurdRepository();

    await expectLater(repository.deleteAvatarPhoto(), throwsStateError);
  });

  test('offline referans kodu sunucu ödülü üretmez', () async {
    final repository = OfflineZanKurdRepository();

    final result = await repository.redeemReferralCode('ZK-HEVAL');

    expect(result.status, ReferralStatus.networkError);
    expect(result.isSuccess, isFalse);
    expect(result.coinsAwarded, 0);
  });

  test(
    'offline sosyal akış sahte çevrimiçi oda veya eşleşme üretmez',
    () async {
      final repository = OfflineZanKurdRepository();

      await expectLater(
        repository.loadMatchmakingCategories(),
        throwsStateError,
      );
      await expectLater(repository.createOnlineRoom(), throwsStateError);
      await expectLater(
        repository.joinOnlineRoom('ZK-ABCDEF0123'),
        throwsStateError,
      );
      await expectLater(
        repository.loadRoomSnapshot('room-1'),
        throwsStateError,
      );
      await expectLater(repository.joinMatchmaking('Ziman'), throwsStateError);
      await expectLater(repository.cancelMatchmaking(), throwsStateError);
    },
  );

  test('offline turnuva sahte bot şeması veya maç sonucu üretmez', () async {
    final repository = OfflineZanKurdRepository();

    await expectLater(repository.joinTournament(), throwsStateError);
    await expectLater(repository.loadTournamentBracket(), throwsStateError);
    await expectLater(
      repository.submitTournamentMatch(
        matchId: 'offline-match',
        playerScore: 640,
        opponentScore: 0,
      ),
      throwsStateError,
    );
  });

  test('offline fotoğraf yükleme uzak başarı taklidi yapmaz', () async {
    final repository = OfflineZanKurdRepository();

    await expectLater(
      repository.uploadAvatarPhoto(Uint8List.fromList([1, 2, 3]), 'image/png'),
      throwsStateError,
    );
  });

  test('offline soru raporu gönderilmiş gibi davranmaz', () async {
    final repository = OfflineZanKurdRepository();

    await expectLater(
      repository.reportQuestion(repository.questions.first, 'yanlış içerik'),
      throwsStateError,
    );
  });

  test('offline ekonomi sunucu bakiyesi veya ödülü taklit etmez', () async {
    final repository = OfflineZanKurdRepository();

    // Çevrimdışı güvenli dönüş: kırmızı ekran yerine sahte başarı yok.
    expect(await repository.loadCoinBalance(), 0);
    expect(await repository.canSpinToday(), isFalse);
    expect(await repository.awardSpinCoins(), 0);
    expect(await repository.spendCoins(10, 'purchase_test'), isFalse);
    final claim = await repository.awardQuizCoins(
      score: 1000,
      correctCount: 10,
      bestStreak: 10,
      totalQuestions: 10,
    );
    expect(claim.amount, 0);
    expect(claim.dailyCapReached, isFalse);
  });

  test('offline sunucu ödülleri sahte coin üretmez', () async {
    final repository = OfflineZanKurdRepository();

    expect(
      await repository.claimMissionReward(
        missionKey: 'daily_quiz',
        fallbackReward: 50,
      ),
      0,
    );
    expect(await repository.claimTournamentReward(), 0);
    expect(await repository.claimTournamentChampionReward(), 0);
  });

  test(
    'offline contest sonucu veya ödülü doğrulanmış gibi davranmaz',
    () async {
      final repository = OfflineZanKurdRepository();

      expect(
        await repository.submitContestEntry(
          contestId: 'contest-offline',
          correctCount: 10,
        ),
        isNull,
      );
      expect(await repository.claimContestReward('contest-offline'), isNull);
    },
  );

  test(
    'offline uzak etkinlik ve turnuva sıralaması mock içerik göstermez',
    () async {
      final repository = OfflineZanKurdRepository();

      expect(await repository.loadTodayContest(), isNull);
      expect(await repository.loadTournamentStandings(), isEmpty);
    },
  );

  test('offline seri dondurma tahsil edilmiş gibi davranmaz', () async {
    final repository = OfflineZanKurdRepository();

    final result = await repository.spendStreakFreeze(
      idempotencyKey: 'offline-freeze-1',
    );

    expect(result.outcome, StreakFreezeChargeOutcome.failed);
    expect(result.succeeded, isFalse);
  });

  test('offline sunucu XP toplamı üretmez', () async {
    final repository = OfflineZanKurdRepository();

    expect(repository.awardXp(120), throwsA(isA<StateError>()));
    expect(repository.awardRoomXp('room-offline'), throwsA(isA<StateError>()));
  });

  test('offline favoriler yalnız gerçek seçimleri kalıcı tutar', () async {
    final first = OfflineZanKurdRepository();
    final question = first.playableQuestions.first;

    expect(await first.loadFavoriteQuestions(), isEmpty);
    expect(await first.toggleFavoriteQuestion(question, true), isTrue);

    final second = OfflineZanKurdRepository();
    expect(await second.isFavoriteQuestion(question), isTrue);
    expect(
      (await second.loadFavoriteQuestions()).map((item) => item.id),
      contains(question.id),
    );

    expect(await second.toggleFavoriteQuestion(question, false), isFalse);
    final third = OfflineZanKurdRepository();
    expect(await third.isFavoriteQuestion(question), isFalse);
    expect(await third.loadFavoriteQuestions(), isEmpty);
  });

  test('offline ders tamamlanması cihazda kalıcıdır', () async {
    final first = OfflineZanKurdRepository();
    expect(await first.markLessonCompleted('lesson-1'), isTrue);

    final second = OfflineZanKurdRepository();
    expect(await second.loadCompletedLessonIds(), contains('lesson-1'));
  });
}
