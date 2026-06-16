# Joker Sistemi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** QuizScreen'e 4 coin'li joker ekle — 50/50 (artık ücretli), Seyirci Anketi, Çift Cevap, Soru Değiştir (solo only) — ve Supabase'e atomik `spend_coins` RPC ile sunucu tarafı bakiye düşümü entegre et.

**Architecture:** Yeni `WildcardType`/`WildcardState` modeli soru başına joker kullanımını takip eder. Repository'ye `spendCoins(amount, reason)` eklenir. `quiz_screen.dart` iyimser yerel düşüm yapar, arka planda async `spendCoins` çağırır. Supabase'e bakiye doğrulayan + negatif `coin_transactions` satırı yazan `spend_coins` SQL fonksiyonu eklenir.

**Tech Stack:** Flutter/Dart 3, Provider, Supabase PostgreSQL RPC, `dart:math` (seyirci anketi için tohumlu RNG), `package:flutter_test`.

---

## Dosya Haritası

| Dosya | İşlem | Sorumluluk |
|-------|-------|-----------|
| `lib/src/models/wildcard.dart` | Oluştur | `WildcardType` enum + maliyet/ikon/etiket + `WildcardState` |
| `lib/src/data/zankurd_repository.dart` | Değiştir | `spendCoins` abstract metot ekle |
| `lib/src/data/mock_zankurd_repository.dart` | Değiştir | `spendCoins` yerel `_mockCoins` düşümü |
| `lib/src/data/supabase_zankurd_repository.dart` | Değiştir | `spendCoins` → `spend_coins` RPC çağrısı |
| `supabase/spend_coins.sql` | Oluştur | SQL fonksiyon tanımı (referans için) |
| `lib/src/screens/quiz_screen.dart` | Değiştir | State eklentileri + 4 joker mekanikleri + UI |
| `test/wildcard_test.dart` | Oluştur | `WildcardState` ve `spendCoins` birim testleri |

---

## Task 1: `wildcard.dart` — Model

**Dosyalar:**
- Oluştur: `zankurd_mobile/lib/src/models/wildcard.dart`

- [ ] **Adım 1: Dosyayı yaz**

```dart
import 'package:flutter/material.dart';

enum WildcardType { fiftyFifty, audience, doubleAnswer, changeQuestion }

extension WildcardTypeDetails on WildcardType {
  int get coinCost => switch (this) {
    WildcardType.fiftyFifty     => 20,
    WildcardType.audience       => 30,
    WildcardType.doubleAnswer   => 50,
    WildcardType.changeQuestion => 40,
  };

  IconData get icon => switch (this) {
    WildcardType.fiftyFifty     => Icons.auto_awesome_outlined,
    WildcardType.audience       => Icons.groups_outlined,
    WildcardType.doubleAnswer   => Icons.check_circle_outline,
    WildcardType.changeQuestion => Icons.refresh_outlined,
  };

  String label(bool isKu) => switch (this) {
    WildcardType.fiftyFifty     => isKu ? 'Nîv bi Nîv'        : '50/50',
    WildcardType.audience       => isKu ? 'Ji Temaşevanan'     : 'Seyirciye Sor',
    WildcardType.doubleAnswer   => isKu ? 'Du Bersiv'          : 'Çift Cevap',
    WildcardType.changeQuestion => isKu ? 'Pirsê Biguhere'     : 'Soru Değiştir',
  };
}

class WildcardState {
  const WildcardState({
    this.fiftyFiftyUsed = false,
    this.audienceUsed = false,
    this.doubleAnswerActivated = false,
    this.changeQuestionUsed = false,
  });

  final bool fiftyFiftyUsed;
  final bool audienceUsed;
  final bool doubleAnswerActivated;
  final bool changeQuestionUsed;

  bool isUsed(WildcardType type) => switch (type) {
    WildcardType.fiftyFifty     => fiftyFiftyUsed,
    WildcardType.audience       => audienceUsed,
    WildcardType.doubleAnswer   => doubleAnswerActivated,
    WildcardType.changeQuestion => changeQuestionUsed,
  };

  WildcardState copyWith({
    bool? fiftyFiftyUsed,
    bool? audienceUsed,
    bool? doubleAnswerActivated,
    bool? changeQuestionUsed,
  }) => WildcardState(
    fiftyFiftyUsed: fiftyFiftyUsed ?? this.fiftyFiftyUsed,
    audienceUsed: audienceUsed ?? this.audienceUsed,
    doubleAnswerActivated: doubleAnswerActivated ?? this.doubleAnswerActivated,
    changeQuestionUsed: changeQuestionUsed ?? this.changeQuestionUsed,
  );

  WildcardState resetForNextQuestion() => const WildcardState();
}
```

- [ ] **Adım 2: Analiz — hata yok mu?**

```powershell
cd zankurd_mobile; dart analyze lib/src/models/wildcard.dart
```

Beklenen: `No issues found!`

---

## Task 2: Repository — `spendCoins` sözleşmesi

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/data/zankurd_repository.dart`
- Değiştir: `zankurd_mobile/lib/src/data/mock_zankurd_repository.dart`
- Değiştir: `zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart`

- [ ] **Adım 1: `zankurd_repository.dart`'a abstract metot ekle**

`loadCoinBalance();` satırından hemen sonrasına ekle:

```dart
  /// Oyuncunun coin bakiyesinden [amount] kadar düşer.
  /// Bakiye yeterli değilse false, başarılıysa true döner.
  Future<bool> spendCoins(int amount, String reason);
```

- [ ] **Adım 2: `mock_zankurd_repository.dart`'a impl ekle**

`awardQuizCoins(...)` metodunun üstüne ekle:

```dart
  @override
  Future<bool> spendCoins(int amount, String reason) async {
    if (_mockCoins < amount) return false;
    _mockCoins -= amount;
    return true;
  }
```

- [ ] **Adım 3: `supabase_zankurd_repository.dart`'a impl ekle**

`awardQuizCoins(...)` metodunun üstüne ekle:

```dart
  @override
  Future<bool> spendCoins(int amount, String reason) async {
    try {
      final _ = client.auth.currentUser ?? await signInAnonymously();
      await ensureProfile();
      final response = await client.rpc(
        'spend_coins',
        params: {'p_amount': amount, 'p_reason': reason},
      );
      if (response is Map<String, dynamic>) {
        return response['success'] as bool? ?? false;
      }
      return false;
    } catch (error, stack) {
      _recordError(error, stack, reason: 'spendCoins failed');
      return false;
    }
  }
```

- [ ] **Adım 4: Analiz**

```powershell
cd zankurd_mobile; dart analyze lib/src/data/
```

Beklenen: `No issues found!`

---

## Task 3: Supabase `spend_coins` SQL fonksiyonu

**Dosyalar:**
- Oluştur: `zankurd_mobile/supabase/spend_coins.sql` (referans)
- Çalıştır: Python urllib ile deploy

- [ ] **Adım 1: SQL dosyasını yaz**

```sql
-- supabase/spend_coins.sql
-- Oyuncunun coin bakiyesini kontrol eder; yeterliyse negatif işlem yazar.
create or replace function public.spend_coins(p_amount integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid    := auth.uid();
  v_balance integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  select coalesce(sum(amount), 0) into v_balance
  from coin_transactions
  where player_id = v_uid;

  if v_balance < p_amount then
    return jsonb_build_object('success', false, 'balance', v_balance);
  end if;

  insert into coin_transactions (player_id, amount, reason)
  values (v_uid, -p_amount, p_reason);

  return jsonb_build_object('success', true, 'balance', v_balance - p_amount);
end;
$$;
```

- [ ] **Adım 2: Python deploy script'i yaz (`_deploy_spend.py`)**

```python
import urllib.request, json, os

token = os.environ['SB_TOKEN']
project = 'hupivnxgjtsfafulzspo'
url = f'https://api.supabase.com/v1/projects/{project}/database/query'

sql = """
create or replace function public.spend_coins(p_amount integer, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid    := auth.uid();
  v_balance integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;
  select coalesce(sum(amount), 0) into v_balance
  from coin_transactions where player_id = v_uid;
  if v_balance < p_amount then
    return jsonb_build_object('success', false, 'balance', v_balance);
  end if;
  insert into coin_transactions (player_id, amount, reason)
  values (v_uid, -p_amount, p_reason);
  return jsonb_build_object('success', true, 'balance', v_balance - p_amount);
end;
$$;
"""

body = json.dumps({'query': sql}).encode('utf-8')
req = urllib.request.Request(url, data=body, headers={
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json',
    'User-Agent': 'curl/8.0',
}, method='POST')

with urllib.request.urlopen(req) as r:
    print(r.read().decode('utf-8'))
print('spend_coins fonksiyonu deploy edildi.')
```

- [ ] **Adım 3: Deploy et**

```powershell
$env:SB_TOKEN = "<PAT_TOKEN>"
python _deploy_spend.py
```

Beklenen: `spend_coins fonksiyonu deploy edildi.`

- [ ] **Adım 4: `_deploy_spend.py` sil**

```powershell
Remove-Item _deploy_spend.py
```

---

## Task 4: `quiz_screen.dart` — State temeli + coin bakiyesi

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: Import ekle**

Dosyanın başındaki import bloğuna ekle:

```dart
import 'dart:math';

import '../models/wildcard.dart';
```

- [ ] **Adım 2: `_QuizScreenState`'e yeni state alanları ekle**

`Set<String> hiddenAnswers = const {};` satırından **sonra** şunları ekle:

```dart
  late List<QuizQuestion> _questions;
  WildcardState _wildcard = const WildcardState();
  String _firstAttemptAnswer = '';
  Map<String, double>? _audiencePoll;
  int _coinBalance = 0;
```

- [ ] **Adım 3: `question` getter'ını güncelle**

```dart
  // ESKİ:
  QuizQuestion get question => widget.questions[index];
  // YENİ:
  QuizQuestion get question => _questions[index];
```

- [ ] **Adım 4: `initState()`'e iki satır ekle**

`_isKu = context.langProvider.isKu;` satırından **sonra**:

```dart
    _questions = List.of(widget.questions);
    _loadCoinBalance();
```

- [ ] **Adım 5: `_loadCoinBalance()` metodu ekle** (dispose'dan önce herhangi bir yere):

```dart
  void _loadCoinBalance() {
    widget.repository.loadCoinBalance().then((balance) {
      if (mounted) setState(() => _coinBalance = balance);
    });
  }
```

- [ ] **Adım 6: `_next()` içinde setState bloğuna state sıfırlama ekle**

`setState(() {` içinde `hiddenAnswers = const {};` satırını şunla değiştir:

```dart
      _wildcard = const WildcardState();
      _firstAttemptAnswer = '';
      _audiencePoll = null;
      hiddenAnswers = const {};
```

- [ ] **Adım 7: `_ScoreHeader`'a `coinBalance` parametresi ekle**

`_ScoreHeader` sınıfını güncelle:

```dart
class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.streak,
    required this.progress,
    required this.coinBalance,
    super.key,
  });

  final int score;
  final int streak;
  final String progress;
  final int coinBalance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: context.s('Pûan', 'Puan'), value: '$value'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: streak),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                _Metric(label: context.s('Rêz', 'Seri'), value: '$value'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(label: context.s('Pirs', 'Soru'), value: progress),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Metric(
            label: context.s('Coin', 'Coin'),
            value: '$coinBalance',
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Adım 8: `_ScoreHeader` çağrısını güncelle** (build() içinde):

```dart
                _ScoreHeader(
                  score: score,
                  streak: streak,
                  progress: '${index + 1}/${widget.questions.length}',
                  coinBalance: _coinBalance,
                ),
```

- [ ] **Adım 9: Analiz**

```powershell
cd zankurd_mobile; dart analyze lib/src/screens/quiz_screen.dart
```

Beklenen: `No issues found!`

---

## Task 5: 50/50 joker — coin maliyeti

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: `_useFiftyFifty()` metodunu değiştir**

Mevcut `_useFiftyFifty()` metodunun tamamını aşağıdakiyle değiştir:

```dart
  void _useFiftyFifty() {
    const cost = 20;
    if (_wildcard.fiftyFiftyUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(fiftyFiftyUsed: true);
      hiddenAnswers = question.answers
          .where((a) => a != question.correctAnswer)
          .take(2)
          .toSet();
    });
    widget.repository
        .spendCoins(cost, 'wildcard_fifty_fifty')
        .catchError((_) {});
  }
```

---

## Task 6: Seyirci Anketi joker

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: `_useAudience()` ve `_buildAudiencePoll()` metotlarını ekle**

`_useFiftyFifty()` metodundan sonrasına ekle:

```dart
  void _useAudience() {
    const cost = 30;
    if (_wildcard.audienceUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(audienceUsed: true);
      _audiencePoll = _buildAudiencePoll();
    });
    widget.repository
        .spendCoins(cost, 'wildcard_audience')
        .catchError((_) {});
  }

  Map<String, double> _buildAudiencePoll() {
    final seed = question.id.codeUnits.fold<int>(0, (s, u) => s + u);
    final rng = Random(seed);

    // 50/50 aktifse sadece görünür şıkları say
    final visible = question.answers
        .where((a) => !hiddenAnswers.contains(a))
        .toList();
    final wrongs = visible.where((a) => a != question.correctAnswer).toList();

    // Doğru cevap %50-70 oy alır
    final correctShare = 0.50 + rng.nextDouble() * 0.20;
    var remaining = 1.0 - correctShare;

    final poll = <String, double>{};
    for (var i = 0; i < wrongs.length; i++) {
      if (i == wrongs.length - 1) {
        poll[wrongs[i]] = remaining < 0 ? 0.0 : remaining;
      } else {
        final share = remaining * (0.15 + rng.nextDouble() * 0.45);
        poll[wrongs[i]] = share;
        remaining -= share;
      }
    }
    poll[question.correctAnswer] = correctShare;
    return poll;
  }
```

- [ ] **Adım 2: `_AnswerButton`'a `audiencePercent` parametresi ekle**

`_AnswerButton` sınıfının constructor'ına `this.audiencePercent` ekle:

```dart
class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.answer,
    required this.selected,
    required this.correct,
    required this.disabled,
    required this.onTap,
    this.firstAttemptWrong = false,
    this.audiencePercent,
    super.key,
  });

  final String answer;
  final bool selected;
  final bool correct;
  final bool disabled;
  final VoidCallback onTap;
  final bool firstAttemptWrong;
  final double? audiencePercent;
```

- [ ] **Adım 3: `_AnswerButton.build()`'e poll bar ekle**

`_AnswerButton.build()` içinde, `child: Row(...)` olan `AnimatedContainer`'ın `child`'ını `Column`'a dönüştür:

```dart
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      answer,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (correct)
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.correct,
                    ),
                  if (wrong)
                    const Icon(Icons.cancel_outlined, color: AppTheme.wrong),
                ],
              ),
              if (audiencePercent != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: audiencePercent!.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: AppTheme.borderColor(context),
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(audiencePercent! * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
```

- [ ] **Adım 4: `_buildQuestionPanel()`'da `_AnswerButton` çağrısına `audiencePercent` geçir**

Mevcut `_AnswerButton(...)` çağrısını güncelle:

```dart
                  child: _AnswerButton(
                    answer: answer,
                    selected: selectedAnswer == answer,
                    correct: answered && answer == question.correctAnswer,
                    disabled: answered || answer == _firstAttemptAnswer,
                    firstAttemptWrong: !answered && answer == _firstAttemptAnswer,
                    audiencePercent: _audiencePoll?[answer],
                    onTap: () => _answer(answer),
                  ),
```

---

## Task 7: Çift Cevap joker

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: `_activateDoubleAnswer()` metodunu ekle** (`_useAudience()` sonrasına):

```dart
  void _activateDoubleAnswer() {
    const cost = 50;
    if (_wildcard.doubleAnswerActivated ||
        _coinBalance < cost ||
        answered ||
        _firstAttemptAnswer.isNotEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(doubleAnswerActivated: true);
    });
    widget.repository
        .spendCoins(cost, 'wildcard_double_answer')
        .catchError((_) {});
  }
```

- [ ] **Adım 2: `_answer()` metodunun başına çift-cevap ilk yanlış logic'i ekle**

`_answer()` içinde `if (answered) return;` satırından **hemen sonra**:

```dart
    // Çift Cevap aktifse ve ilk deneme yanlışsa: göster ama kilitleme
    if (_wildcard.doubleAnswerActivated &&
        _firstAttemptAnswer.isEmpty &&
        answer != question.correctAnswer) {
      HapticFeedback.heavyImpact();
      setState(() => _firstAttemptAnswer = answer);
      return;
    }
```

- [ ] **Adım 3: `_AnswerButton`'daki `wrong` hesabını güncelle**

`_AnswerButton.build()` içinde:

```dart
    final wrong = (selected && !correct && disabled) || firstAttemptWrong;
```

Bu satır zaten Task 6'da doğru yazılmış (firstAttemptWrong kullanıyor). Analiz çalıştır.

---

## Task 8: Soru Değiştir joker (solo only)

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: `_isSoloMode` getter ekle**

```dart
  bool get _isSoloMode => widget.room.id == null || widget.botRace;
```

- [ ] **Adım 2: `_changeQuestion()` metodunu ekle** (`_activateDoubleAnswer()` sonrasına):

```dart
  void _changeQuestion() {
    const cost = 40;
    if (!_isSoloMode ||
        _wildcard.changeQuestionUsed ||
        _coinBalance < cost ||
        answered) return;

    final category = question.category;
    final difficulty = question.difficulty;
    final usedIds = _questions.map((q) => q.id).toSet();

    // Önce aynı kategori + zorlukta ara
    var candidates = widget.repository.questions
        .where((q) =>
            q.category == category &&
            q.difficulty == difficulty &&
            !usedIds.contains(q.id))
        .toList();

    // Yeterli yoksa aynı kategoride herhangi bir zorluk
    if (candidates.isEmpty) {
      candidates = widget.repository.questions
          .where((q) => q.category == category && !usedIds.contains(q.id))
          .toList();
    }

    if (candidates.isEmpty) return; // değiştirilecek soru bulunamadı

    HapticFeedback.selectionClick();
    final replacement = candidates[Random().nextInt(candidates.length)];

    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(changeQuestionUsed: true);
      _questions[index] = replacement;
      hiddenAnswers = const {};
      _audiencePoll = null;
    });
    _markQuestionSeen();
    widget.repository
        .spendCoins(cost, 'wildcard_change_question')
        .catchError((_) {});
  }
```

---

## Task 9: Joker satırı UI + `_WildcardButton` widget

**Dosyalar:**
- Değiştir: `zankurd_mobile/lib/src/screens/quiz_screen.dart`

- [ ] **Adım 1: `_onWildcardTap()` yönlendirici ekle**

```dart
  void _onWildcardTap(WildcardType type) => switch (type) {
    WildcardType.fiftyFifty     => _useFiftyFifty(),
    WildcardType.audience       => _useAudience(),
    WildcardType.doubleAnswer   => _activateDoubleAnswer(),
    WildcardType.changeQuestion => _changeQuestion(),
  };
```

- [ ] **Adım 2: `_buildWildcardRow()` widget builder ekle**

```dart
  Widget _buildWildcardRow() {
    final jokers = [
      WildcardType.fiftyFifty,
      WildcardType.audience,
      WildcardType.doubleAnswer,
      if (_isSoloMode) WildcardType.changeQuestion,
    ];
    return Row(
      children: [
        for (var i = 0; i < jokers.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _buildWildcardButton(jokers[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildWildcardButton(WildcardType type) {
    final used = _wildcard.isUsed(type);
    final active = type == WildcardType.doubleAnswer && used;
    final canAfford = _coinBalance >= type.coinCost;
    // active doubleAnswer: görsel olarak vurgulu ama tıklanamaz
    final isEnabled = !used && canAfford && !answered;

    return _WildcardButton(
      type: type,
      isKu: _isKu,
      isEnabled: isEnabled,
      isActive: active,
      onTap: () => _onWildcardTap(type),
    );
  }
```

- [ ] **Adım 3: `build()` içindeki mevcut joker+next Row'u yeni layout ile değiştir**

Eski kod (quiz_screen.dart:230-258):
```dart
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: answered ? null : _useFiftyFifty,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('50/50'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: answered && !completing
                            ? () => _next()
                            : null,
                        icon: Icon(
                          isLastQuestion
                              ? Icons.flag_outlined
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          isLastQuestion
                              ? context.s('Qediya', 'Bitir')
                              : context.s('Piştî vê', 'Sonraki'),
                        ),
                      ),
                    ),
                  ],
                ),
```

Yeni kod:
```dart
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWildcardRow(),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: answered && !completing ? () => _next() : null,
                      icon: Icon(
                        isLastQuestion
                            ? Icons.flag_outlined
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        isLastQuestion
                            ? context.s('Qediya', 'Bitir')
                            : context.s('Piştî vê', 'Sonraki'),
                      ),
                    ),
                  ],
                ),
```

- [ ] **Adım 4: `_WildcardButton` widget sınıfını ekle** (dosyanın sonuna, diğer private sınıfların yanına):

```dart
class _WildcardButton extends StatelessWidget {
  const _WildcardButton({
    required this.type,
    required this.isKu,
    required this.isEnabled,
    required this.isActive,
    required this.onTap,
  });

  final WildcardType type;
  final bool isKu;
  final bool isEnabled;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (isEnabled || isActive) ? 1.0 : 0.35,
      child: OutlinedButton(
        onPressed: isEnabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive
              ? AppTheme.accent.withValues(alpha: 0.15)
              : null,
          side: isActive
              ? const BorderSide(color: AppTheme.accent)
              : BorderSide(color: AppTheme.borderColor(context)),
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: const Size(0, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 16),
            const SizedBox(height: 2),
            Text(
              '${type.coinCost}c',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Adım 5: Tam analiz**

```powershell
cd zankurd_mobile; dart analyze lib/
```

Beklenen: `No issues found!`

---

## Task 10: Birim testleri

**Dosyalar:**
- Oluştur: `zankurd_mobile/test/wildcard_test.dart`

- [ ] **Adım 1: Test dosyasını yaz**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';

void main() {
  group('WildcardState', () {
    test('başlangıç — tüm flag\'ler false', () {
      const state = WildcardState();
      expect(state.fiftyFiftyUsed, isFalse);
      expect(state.audienceUsed, isFalse);
      expect(state.doubleAnswerActivated, isFalse);
      expect(state.changeQuestionUsed, isFalse);
    });

    test('isUsed — doğru flag\'i döner', () {
      const state = WildcardState(fiftyFiftyUsed: true);
      expect(state.isUsed(WildcardType.fiftyFifty), isTrue);
      expect(state.isUsed(WildcardType.audience), isFalse);
      expect(state.isUsed(WildcardType.doubleAnswer), isFalse);
      expect(state.isUsed(WildcardType.changeQuestion), isFalse);
    });

    test('copyWith — yalnızca belirtilen alanı günceller', () {
      const state = WildcardState(fiftyFiftyUsed: true);
      final updated = state.copyWith(audienceUsed: true);
      expect(updated.fiftyFiftyUsed, isTrue);
      expect(updated.audienceUsed, isTrue);
      expect(updated.doubleAnswerActivated, isFalse);
    });

    test('resetForNextQuestion — tüm flag\'leri temizler', () {
      const used = WildcardState(
        fiftyFiftyUsed: true,
        audienceUsed: true,
        doubleAnswerActivated: true,
        changeQuestionUsed: true,
      );
      final reset = used.resetForNextQuestion();
      expect(reset.fiftyFiftyUsed, isFalse);
      expect(reset.audienceUsed, isFalse);
      expect(reset.doubleAnswerActivated, isFalse);
      expect(reset.changeQuestionUsed, isFalse);
    });

    test('coin maliyetleri doğru', () {
      expect(WildcardType.fiftyFifty.coinCost, 20);
      expect(WildcardType.audience.coinCost, 30);
      expect(WildcardType.doubleAnswer.coinCost, 50);
      expect(WildcardType.changeQuestion.coinCost, 40);
    });
  });

  group('spendCoins — MockZanKurdRepository', () {
    late MockZanKurdRepository repo;

    setUp(() => repo = MockZanKurdRepository());

    test('bakiye yeterliyse true döner ve coin düşer', () async {
      final initial = await repo.loadCoinBalance();
      final success = await repo.spendCoins(100, 'test');
      expect(success, isTrue);
      final after = await repo.loadCoinBalance();
      expect(after, initial - 100);
    });

    test('bakiye yetersizse false döner, coin değişmez', () async {
      final initial = await repo.loadCoinBalance();
      final success = await repo.spendCoins(initial + 1, 'test');
      expect(success, isFalse);
      expect(await repo.loadCoinBalance(), initial);
    });

    test('tam bakiyeyi harcamak mümkün', () async {
      final balance = await repo.loadCoinBalance();
      final success = await repo.spendCoins(balance, 'test');
      expect(success, isTrue);
      expect(await repo.loadCoinBalance(), 0);
    });

    test('sıfır bakiye ile harcama yapılamaz', () async {
      final balance = await repo.loadCoinBalance();
      await repo.spendCoins(balance, 'empty');
      final success = await repo.spendCoins(1, 'after_empty');
      expect(success, isFalse);
    });
  });
}
```

- [ ] **Adım 2: Testleri çalıştır**

```powershell
cd zankurd_mobile; flutter test test/wildcard_test.dart --reporter expanded
```

Beklenen: 9 test — tümü yeşil.

- [ ] **Adım 3: Tüm test süitini çalıştır**

```powershell
flutter test --reporter expanded
```

Beklenen: Tüm testler geçer, regresyon yok.

---

## Task 11: Commit

- [ ] **Adım 1: Dosyaları ekle ve commit yap**

```powershell
cd "C:\Users\AMARGİ\Desktop\pirs kurmanci"
git add zankurd_mobile/lib/src/models/wildcard.dart
git add zankurd_mobile/lib/src/data/zankurd_repository.dart
git add zankurd_mobile/lib/src/data/mock_zankurd_repository.dart
git add zankurd_mobile/lib/src/data/supabase_zankurd_repository.dart
git add zankurd_mobile/lib/src/screens/quiz_screen.dart
git add zankurd_mobile/supabase/spend_coins.sql
git add zankurd_mobile/test/wildcard_test.dart
git commit -m "feat(wildcards): 4 coin-gated jokers + Supabase spend_coins RPC"
```

---

## Self-Review Kontrol Listesi

- [x] **Spec coverage:** 50/50 (Task 5), Seyirci (Task 6), Çift Cevap (Task 7), Soru Değiştir (Task 8), coin UI (Task 4+9), spendCoins RPC (Task 2+3), testler (Task 10) — tümü kapsanmış.
- [x] **Placeholder taraması:** Kod blokları tam, "TBD" yok.
- [x] **Tip tutarlılığı:** `WildcardType`, `WildcardState`, `spendCoins(int, String)` — Task 1'de tanımlanıp tüm task'larda tutarlı kullanılıyor.
- [x] **`dart:math`:** Task 4'te import ekleniyor, Task 6 ve 8'de `Random()` kullanılıyor.
- [x] **`_firstAttemptAnswer` sıfırlaması:** Task 4'te `_next()` içinde sıfırlanıyor.
- [x] **Online mod koruması:** `_isSoloMode` getter (Task 8) ve `_buildWildcardRow()` (Task 9) Soru Değiştir'i online'da gizliyor.
