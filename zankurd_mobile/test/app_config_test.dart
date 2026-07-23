import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';

void main() {
  test('bundled Supabase defaults remain available as fallback values', () {
    expect(AppConfig.supabaseUrl, 'https://hupivnxgjtsfafulzspo.supabase.co');
    expect(
      AppConfig.supabaseAnonKey,
      'sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s',
    );
  });

  test('ordinary test builds do not auto-enable live Supabase', () {
    expect(AppConfig.hasExplicitSupabaseConfig, isFalse);
    expect(AppConfig.usesBundledSupabaseDefaults, isFalse);
    expect(AppConfig.hasSupabaseConfig, isFalse);
  });
}
