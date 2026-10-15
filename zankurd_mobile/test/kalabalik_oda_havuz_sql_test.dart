// Kalabalık odada giriş ücreti havuzu: eski kural (kazanan 2x ücret) N
// oyuncuda havuzun yalnız iki payını dağıtıp kalanını yok ediyordu. Kural
// SQL'de yaşadığından istemci testleri bunu göremez; bekçi göçün metnine
// bakar. Dağıtım hesabı canlıda dört senaryoyla denendi (2026-10-16).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/2026-10-16_kalabalik_oda_havuz.sql',
  ).readAsStringSync();

  test('havuz yalnız kalabalık odada; iki kişilik kural aynen kalır', () {
    expect(sql, contains('(r.is_custom and r.max_players > 2)'));
    expect(sql, contains('if v_entry_fee > 0 and v_crowd then'));
    expect(sql, contains('elsif v_entry_fee > 0 then'));
    expect(sql, contains('v_amount := v_amount + (v_entry_fee * 2);'));
  });

  test('havuz katılan herkesten, pay yalnız kalanlara, 50/30/20', () {
    expect(sql, contains('count(*)::integer * v_entry_fee into v_pool'));
    expect(sql, contains('and rp.left_at is null'));
    expect(sql, contains('(values (1, 50), (2, 30), (3, 20))'));
    expect(sql, contains('if not v_left then'));
    expect(sql, contains('greatest(v_pool - v_distributed, 0)'));
  });

  test('günlük sınır yalnız taban ödülü sayar', () {
    expect(sql, contains('values (v_player_id, v_today, v_base_paid)'));
    expect(sql, contains('v_today date := public.app_today();'));
  });
}
