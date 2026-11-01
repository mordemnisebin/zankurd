// G16 browser-only preview; no production auth/database or device is used.
// flutter run -d web-server --web-port=8766 -t tool/g16_invite_preview.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room_invite.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/room_invite_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final repository = MockZanKurdRepository();
  LocalProgressScope.bind(repository.currentUserId!);
  repository.seedRoomInviteForTesting(
    RoomInvite(
      id: 'g16-legacy-preview',
      roomId: 'g16-room',
      roomCode: 'G16',
      inviterId: 'friend',
      inviterName: 'Rojda',
      categoryName: 'Ziman',
      playerCount: 2,
      maxPlayers: 8,
      createdAt: DateTime.now(),
      hasLegacyTerms: true,
    ),
  );
  runApp(
    ZanKurdApp(
      repository: repository,
      authProvider: AuthProvider.test(authenticated: true),
      languageProvider: LanguageProvider(initialLang: 'tr'),
      themeProvider: ThemeProvider(initialMode: ThemeMode.light),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RoomInviteCard(repository: repository),
            ),
          ),
        ),
      ),
    ),
  );
}
