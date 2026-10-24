import 'package:flutter/foundation.dart';

/// Kabuktan (AppShell) Profil sekmesini açmasını isteyen küçük kanal.
///
/// Arkadaşlar ekranı kabuğun ÜSTÜNE itilmiş bir sayfadır; misafirin "Hesabını
/// kaydet" satırı ise Profil sekmesindedir. Ekran kabuğa doğrudan
/// erişemediğinden (ve kabuğun sekme durumunu açığa çıkarmak yerine) bu
/// sayaç artırılır, kabuk dinleyip sekmeyi seçer. Bekçi:
/// `test/davet_onboarding_2026_10_24_test.dart`.
class ProfileTabRequest {
  const ProfileTabRequest._();

  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  static void request() => pending.value++;
}
