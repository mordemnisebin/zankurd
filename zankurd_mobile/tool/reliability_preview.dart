// Local simulator QA entrypoint. No production main(), Firebase or Supabase.
// flutter run --no-pub -t tool/reliability_preview.dart -d <simulator-id>
// --dart-define=PREVIEW_PUSH=true: deliver a local foreground event at 5s.
// Default: no event; the visible card must find the invitation by polling.
// --dart-define=PREVIEW_LANG=ku --dart-define=PREVIEW_DARK=true
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/paid_freeze_intent.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room_invite.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/services/foreground_push_center.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _PreviewRepository extends MockZanKurdRepository {
  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
    bool allowLegacyFallback = true,
  }) async {
    if (idempotencyKey ==
        QuizResultProgressReceiptStore.keyFor(
          userId: currentUserId!,
          roomId: 'solo:local-preview',
        )) {
      // This fixture models a charge accepted before its response was lost.
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.alreadyCharged,
        idempotent: true,
      );
    }
    return super.spendStreakFreeze(
      idempotencyKey: idempotencyKey,
      allowLegacyFallback: allowLegacyFallback,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuestionBankLoader.instance.load();
  final repository = _PreviewRepository();
  final owner = repository.currentUserId!;
  LocalProgressScope.bind(owner);
  final now = DateTime.now();
  final played = _day(DateTime(now.year, now.month, now.day - 1));
  final previous = _day(DateTime(now.year, now.month, now.day - 3));
  final bridge = _day(DateTime(now.year, now.month, now.day - 2));
  const round = 'solo:local-preview';
  final receiptKey = QuizResultProgressReceiptStore.keyFor(
    userId: owner,
    roomId: round,
  );
  final intent = PaidFreezeIntent(
    ownerId: owner,
    roundId: round,
    idempotencyKey: receiptKey,
    playedDay: played,
    previousLastDay: previous,
    targetCurrent: 8,
    targetBest: 8,
    playedDays: [previous, played],
    frozenDays: [bridge],
  );
  SharedPreferences.setMockInitialValues({
    'zankurd.onboarding.seen': true,
    'zankurd.profileName.completed.$owner': true,
    'zankurd.navTour.seen': true,
    'zankurd.quiz_tutorial.seen': true,
    LocalProgressScope.physical('zankurd.streak.current'): 7,
    LocalProgressScope.physical('zankurd.streak.best'): 7,
    LocalProgressScope.physical('zankurd.streak.lastDay'): previous,
    receiptKey: jsonEncode(
      QuizResultReceipt(
        stage: QuizResultReceiptStage.freezeChargePending,
        freezeRequested: true,
        paidFreezeIntent: intent,
      ).toJson(),
    ),
  });
  runApp(
    ZanKurdApp(
      repository: repository,
      authProvider: AuthProvider.test(authenticated: true),
      languageProvider: LanguageProvider(
        initialLang: const String.fromEnvironment(
          'PREVIEW_LANG',
          defaultValue: 'tr',
        ),
      ),
      themeProvider: ThemeProvider(
        initialMode: const bool.fromEnvironment('PREVIEW_DARK')
            ? ThemeMode.dark
            : ThemeMode.light,
      ),
      home: AppShell(
        repository: repository,
        connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
      ),
    ),
  );
  Timer(const Duration(seconds: 5), () {
    final room = repository.createRoom();
    repository.seedRoomInviteForTesting(
      RoomInvite(
        id: 'local-preview-invite',
        roomId: room.id ?? 'local-preview-room',
        roomCode: room.code,
        inviterId: 'local-preview-friend',
        inviterName: 'Rojda',
        categoryName: room.category,
        playerCount: 2,
        maxPlayers: 8,
        entryFee: room.entryFee,
        questionCount: room.questionCount,
        secondsPerQuestion: room.secondsPerQuestion,
        createdAt: DateTime.now(),
      ),
    );
    if (const bool.fromEnvironment('PREVIEW_PUSH')) {
      ForegroundPushCenter.emit(
        const ForegroundPush(
          data: {
            'kind': 'room_invite',
            'job_id': 'local-preview-push',
            'invite_id': 'local-preview-invite',
          },
        ),
      );
    }
  });
}
