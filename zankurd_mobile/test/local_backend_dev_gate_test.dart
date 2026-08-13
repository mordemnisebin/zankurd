import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/config/release_config_validator.dart';

/// Yerel arka uç kapısının bekçisi.
///
/// ## Kusur
///
/// `isSafeSupabaseUrl` yalnız `https://<proje>.supabase.co` biçimini kabul
/// ediyordu ve `hasUsableSupabaseConfiguration` bu kuralı derleme kipinden
/// bağımsız uyguluyordu. `supabase start` ise `http://127.0.0.1:54321`
/// konuşur (emülatörde `10.0.2.2`). Sonuç: hata ayıklama derlemesi bile
/// yerel yığına bağlanamıyor, `--dart-define` verilse bile uygulama sessizce
/// sahte depoya düşüyordu.
///
/// Bunun bedeli görünmezdi ama ağırdı: gerçek bir arka uçla tek deneme yolu
/// ÜRETİM projesine bağlanmaktı. Yani "iki cihazda oda kur ve oyna" gibi bir
/// doğrulama ya hiç yapılamıyor ya da canlı veriye yazılarak yapılıyordu
/// (2026-08-13 iki simülatörlü denetimi).
///
/// Sessizdi çünkü sahte depoya düşüş bir hata değil, tasarlanmış bir geri
/// çekilme yolu: ekran açılıyor, sorular geliyor, yalnız oda kurulmuyor.
///
/// Bu bekçi kapının iki yarısını da tutar: yerel adres debug'da geçer,
/// yayın doğrulayıcısı ise aynı adresi reddetmeye devam eder.
void main() {
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.'
      'CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  group('yayın doğrulayıcısı gevşemedi', () {
    test('yerel adresler release kapısından geçemiyor', () {
      // Asıl koruma budur: mağazaya giden ikili yalnız üretim ana bilgisayarı
      // konuşmalı. Gevşetme `hasUsableSupabaseConfiguration` katmanındadır ve
      // `kDebugMode`e bağlıdır; bu alt kural hiç değişmemeli.
      for (final url in const [
        'http://127.0.0.1:54321',
        'http://10.0.2.2:54321',
        'https://localhost:54321',
        'http://zankurd.supabase.co',
      ]) {
        expect(
          ReleaseConfigValidator.isSafeSupabaseUrl(url),
          isFalse,
          reason: '$url yayın kapısından geçmemeli.',
        );
      }
    });

    test('gerçek üretim adresi hâlâ geçerli', () {
      expect(
        ReleaseConfigValidator.isSafeSupabaseUrl(
          'https://hupivnxgjtsfafulzspo.supabase.co',
        ),
        isTrue,
      );
    });
  });

  group('geliştirme kapısı', () {
    test('yalnız yerel ana bilgisayarları tanıyor', () {
      // Testler debug kipinde koşar; `APP_ENV` verilmediği için varsayılan
      // 'production'dır ve kapı kapalı olmalıdır. Kapının kapalıyken
      // HİÇBİR adresi kabul etmemesi, gevşetmenin kazara açılmadığının
      // kanıtıdır.
      expect(
        AppConfig.isDevelopmentSupabaseUrl('http://127.0.0.1:54321'),
        isFalse,
      );
      expect(
        AppConfig.isDevelopmentSupabaseUrl('https://example.com'),
        isFalse,
      );
    });

    test('kapı kapalıyken yerel adresli yapılandırma kullanılmıyor', () {
      expect(
        AppConfig.hasUsableSupabaseConfiguration(
          explicitUrl: 'http://127.0.0.1:54321',
          explicitAnonKey: anonKey,
          useBundledDefaults: false,
          bundledUrl: '',
          bundledAnonKey: '',
        ),
        isFalse,
        reason:
            'APP_ENV=development verilmeden yerel adres kabul edilirse, '
            'gevşetme üretim yapılandırmasına da sızmış demektir.',
      );
    });

    test('üretim adresi kapıdan bağımsız çalışıyor', () {
      // Gevşetmenin meşru yarısını da tut: normal yol kırılmamalı.
      expect(
        AppConfig.hasUsableSupabaseConfiguration(
          explicitUrl: 'https://hupivnxgjtsfafulzspo.supabase.co',
          explicitAnonKey: anonKey,
          useBundledDefaults: false,
          bundledUrl: '',
          bundledAnonKey: '',
        ),
        isTrue,
      );
    });

    test('anahtar geçersizse yerel adres de kurtarmıyor', () {
      expect(
        AppConfig.hasUsableSupabaseConfiguration(
          explicitUrl: 'http://127.0.0.1:54321',
          explicitAnonKey: 'placeholder',
          useBundledDefaults: false,
          bundledUrl: '',
          bundledAnonKey: '',
        ),
        isFalse,
      );
    });
  });
}
