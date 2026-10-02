import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/xp_cache_plan.dart';

void main() {
  test('sunucu daha yüksekse çubuk sunucu toplamını alır', () {
    final plan = XpCachePlan.decide(local: 80, server: 100, xpPending: false);

    expect(plan.step, XpCacheStep.applyServer);
    expect(plan.amount, 100);
  });

  test('yerel öğrenme XP daha yüksekse sunucuya fark gönderilmez', () {
    final plan = XpCachePlan.decide(local: 80, server: 20, xpPending: false);

    expect(plan.step, XpCacheStep.keep);
  });

  test('bekleyen XP varken çubuk ve kuyruk olduğu gibi kalır', () {
    final plan = XpCachePlan.decide(local: 80, server: 20, xpPending: true);

    expect(plan.step, XpCacheStep.keep);
  });

  test('sunucu okunamazsa yerel çubuk durur', () {
    final plan = XpCachePlan.decide(local: 80, server: null, xpPending: false);

    expect(plan.step, XpCacheStep.keep);
  });

  test('eşit toplamda yazım yoktur', () {
    final plan = XpCachePlan.decide(local: 40, server: 40, xpPending: false);

    expect(plan.step, XpCacheStep.keep);
  });
}
