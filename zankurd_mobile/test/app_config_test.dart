import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';

void main() {
  test('ships with production Supabase defaults for ordinary builds', () {
    expect(AppConfig.supabaseUrl, 'https://hupivnxgjtsfafulzspo.supabase.co');
    expect(
      AppConfig.supabaseAnonKey,
      'sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s',
    );
    expect(AppConfig.hasSupabaseConfig, isTrue);
  });

  test('accepts only safe client Supabase keys', () {
    expect(AppConfig.isSafeClientSupabaseKey('sb_publishable_abc123'), isTrue);
    expect(AppConfig.isSafeClientSupabaseKey(' SB_PUBLISHABLE_XYZ '), isTrue);
    expect(AppConfig.isSafeClientSupabaseKey('sb_secret_prod_key'), isFalse);
    expect(
      AppConfig.isSafeClientSupabaseKey('eyJ...service_role...token'),
      isFalse,
    );
    expect(AppConfig.isSafeClientSupabaseKey(''), isFalse);
  });
}
