// Bekçi: fotoğraf değiştirip vazgeçmek KAYITLI fotoğrafı silmemeli (2026-10-17).
//
// Kusur: yükleme hep `{uid}/avatar.jpg` üstüne yazıyordu (upsert); ekrandan
// kaydetmeden çıkınca `dispose()` temizliği o yolu siliyordu — profilin hâlâ
// işaret ettiği kayıtlı fotoğrafı da. Kullanıcı yalnız "yeni fotoğraf
// denedim, vazgeçtim" diyordu; eski fotoğrafı sessizce kayboluyor, avatar kırık
// görünüyordu. Hata yalnız ÖNCEDEN fotoğrafı olan ve vazgeçen kullanıcıda
// çıkar; sınama hesapları çoğunlukla fotoğrafsız olduğundan görünmedi.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

const _old =
    'https://x.supabase.co/storage/v1/object/public/avatars/u1/avatar.jpg?v=1';

class _Repo extends MockZanKurdRepository {
  @override
  Future<AvatarIdentity> loadAvatarIdentity() async =>
      const AvatarIdentity(photoUrl: _old);
}

class _Picker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    AchievementStore.resetInstance();
  });

  Future<void> open(WidgetTester tester, _Repo repo) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AvatarEditorScreen(
                    repository: repo,
                    imagePicker: _Picker(),
                  ),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avatar-pick-photo')));
    await tester.pumpAndSettle();
  }

  testWidgets('yeni fotoğraf seçip vazgeçmek yalnız geçici nesneyi siler', (
    tester,
  ) async {
    final repo = _Repo();
    await open(tester, repo);
    Navigator.of(tester.element(find.byType(AvatarEditorScreen))).pop();
    await tester.pumpAndSettle();

    expect(repo.deletedAvatarUrls, hasLength(1));
    expect(repo.deletedAvatarUrls.single, startsWith('mock://avatar/'));
    expect(repo.deletedAvatarUrls, isNot(contains(_old)));
    expect(
      repo.avatarPhotoDeleted,
      isFalse,
      reason: 'deleteAvatarPhoto sabit avatar.jpg/png yollarını da siler',
    );
  });

  testWidgets('kaydedince eski nesne silinir, yenisi kalır', (tester) async {
    final repo = _Repo();
    await open(tester, repo);
    final save = find.byKey(const ValueKey('avatar-save'));
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.deletedAvatarUrls, [_old]);
    expect(repo.avatarPhotoDeleted, isFalse);
  });

  test('depo yolu: zaman damgalı yükleme ve başkasının yolu yok sayılır', () {
    expect(
      SupabaseZanKurdRepository.avatarObjectPath(_old, 'u1'),
      'u1/avatar.jpg',
    );
    expect(
      SupabaseZanKurdRepository.avatarObjectPath(
        'https://x.supabase.co/storage/v1/object/public/avatars/u1/avatar-17.png',
        'u1',
      ),
      'u1/avatar-17.png',
    );
    expect(SupabaseZanKurdRepository.avatarObjectPath(_old, 'u2'), isNull);
    expect(
      SupabaseZanKurdRepository.avatarObjectPath(
        'https://x/avatars/u1/../u2/avatar.jpg',
        'u1',
      ),
      isNull,
    );
  });

  test('sunucu avatar_url regex\'i zaman damgalı yolu kabul eder', () {
    final sql = File('supabase/2026-10-17_profil_veri.sql').readAsStringSync();
    expect(sql, contains(r"/avatar([-][0-9]+)?[.](jpg|png)([?]v=[0-9]+)?$"));
    final src = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(src, contains(r"/avatar-${DateTime.now().millisecondsSinceEpoch}"));
  });
}
