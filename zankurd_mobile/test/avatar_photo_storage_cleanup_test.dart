import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

/// "Fotoğrafı kaldır" nesneyi depodan silmiyordu (2026-08-02, A-03).
///
/// `uploadAvatarPhoto` görseli SABİT bir yola yazıyor —
/// `{user_id}/avatar.jpg` — ve `avatars` kovası `public = true`, politikası
/// da `using (bucket_id = 'avatars')`, yani anonim dahil herkes okuyabiliyor.
/// Kaldırma aksiyonu ise yalnız `profiles.avatar_url` sütununu boşaltıyordu:
/// `lib/` içinde hiçbir `storage…remove/delete` çağrısı yoktu.
///
/// Sonuç: kullanıcı fotoğrafını kaldırdığını sanıyor, dosya ise tahmin
/// edilebilir bir genel URL'de kalıcı olarak erişilebilir kalıyordu.
///
/// Hesap silme yolu ZATEN doğruydu (`2026-07-05_avatar_showcase.sql` RPC'si
/// `storage.objects`ten kullanıcının klasörünü siliyor); kusur yalnız daha
/// küçük "fotoğrafı kaldır" yolundaydı. Bu ayrım önemli: mağazaların zorunlu
/// kıldığı silme çalışıyordu, ihlal edilen şey kullanıcı beklentisiydi.
///
/// Bekçi iki şeyi sabitler: sözleşmenin varlığı ve silinen yolların hem
/// `.jpg` hem `.png` kapsaması (uzantı içerik türünden seçildiği için önce
/// PNG sonra JPG yükleyen kullanıcı aksi hâlde eski nesneyi yetim bırakırdı).
void main() {
  test('depo sözleşmesi avatar fotoğrafını silmeyi tanımlıyor', () {
    final contract = File(
      'lib/src/data/zankurd_repository.dart',
    ).readAsStringSync();
    expect(
      contract,
      contains('deleteAvatarPhoto()'),
      reason:
          'ZanKurdRepository avatar fotoğrafını depodan silmenin bir yolunu '
          'sunmuyor; kaldırma yalnız profil sütununu boşaltır',
    );
  });

  test('Supabase deposu her iki uzantıyı da kaldırıyor', () {
    final src = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final body = RegExp(
      r'Future<void> deleteAvatarPhoto\(\) async \{(.*?)\n  \}',
      dotAll: true,
    ).firstMatch(src);
    expect(body, isNotNull, reason: 'deleteAvatarPhoto uygulanmamış');

    final impl = body!.group(1)!;
    expect(
      impl,
      contains("storage.from('avatars')"),
      reason: 'silme avatars kovasına gitmiyor',
    );
    expect(impl, contains('.remove('), reason: 'storage remove çağrısı yok');
    expect(impl, contains('avatar.jpg'), reason: '.jpg nesnesi silinmiyor');
    expect(
      impl,
      contains('avatar.png'),
      reason:
          '.png nesnesi silinmiyor — uzantı değiştiren kullanıcı eskisini '
          'yetim bırakır',
    );
  });

  test('kaydetme akışı silmeyi profil yazımından ÖNCE çağırıyor', () {
    final src = File(
      'lib/src/screens/avatar_editor_screen.dart',
    ).readAsStringSync();
    final save = RegExp(
      r'Future<void> _save\(\) async \{(.*?)\n  \}',
      dotAll: true,
    ).firstMatch(src);
    expect(save, isNotNull);

    final body = save!.group(1)!;
    final deleteAt = body.indexOf('deleteAvatarPhoto');
    final updateAt = body.indexOf('updateAvatarIdentity');
    expect(
      deleteAt,
      greaterThan(-1),
      reason: 'kaydetme silmeyi hiç çağırmıyor',
    );
    expect(updateAt, greaterThan(-1));
    expect(
      deleteAt,
      lessThan(updateAt),
      reason:
          'profil önce yazılırsa, silme başarısız olduğunda sütun boşalmış '
          'ama dosya erişilebilir kalır — düzeltilmek istenen durumun aynısı',
    );
  });

  test(
    'silme gerçekten fotoğraf kaldırıldığında YA DA bu oturumda yeni '
    'yüklenip vazgeçildiğinde yapılıyor',
    () {
      final src = File(
        'lib/src/screens/avatar_editor_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        contains(
          '_identity.photoUrl == null &&\n'
          '          (_hadPhotoOnOpen || _uploadedNewPhotoThisSession)',
        ),
        reason:
            '2026-08-14 denetimi: `_hadPhotoOnOpen` yalnız ekran açılırken '
            'ZATEN kayıtlı fotoğrafı kapsar. Kullanıcı hiç fotoğrafsız '
            'açıp bu oturumda YENİ bir fotoğraf yükleyip sonra kaldırırsa '
            '(silmeden kaydederse) eski koşul hep false kalır, silme '
            'çağrısı hiç gitmez — nesne herkese açık kovada yetim kalır.',
      );
    },
  );

  test(
    'kaydedilmeden ekrandan ayrılmak (geri tuşu vb.) bu oturumda '
    'yüklenen fotoğrafı temizler',
    () {
      // `dispose()`, kaydetmeden kapatılan (geri tuşu, kaydırma —
      // hepsi dispose'u tetikler) senaryoyu kapsar: `_save()` hiç
      // çalışmamışsa bu oturumda yüklenen fotoğraf sunucudaki profile
      // hiç yazılmamıştır ama depoda durmaya devam eder (2026-08-14
      // denetimi).
      final src = File(
        'lib/src/screens/avatar_editor_screen.dart',
      ).readAsStringSync();
      final dispose = RegExp(
        r'void dispose\(\) \{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(src);
      expect(dispose, isNotNull, reason: 'dispose() geçersiz kılınmamış');
      final body = dispose!.group(1)!;
      expect(body, contains('_uploadedNewPhotoThisSession'));
      expect(body, contains('!_savedSuccessfully'));
      expect(body, contains('deleteAvatarPhoto()'));
    },
  );

  test('mock depo silme çağrısını kaydediyor', () async {
    final repo = MockZanKurdRepository();
    expect(repo.avatarPhotoDeleted, isFalse);
    await repo.deleteAvatarPhoto();
    expect(
      repo.avatarPhotoDeleted,
      isTrue,
      reason: 'bekçi testler çağrının yapıldığını doğrulayamaz',
    );
  });
}
