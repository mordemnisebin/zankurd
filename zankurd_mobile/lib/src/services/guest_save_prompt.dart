import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_social_buttons.dart';
import '../widgets/guest_account_email_form.dart';
import '../utils/error_reporter.dart';
import '../widgets/sahne/sahne.dart';

/// Misafire "ilerlemeni kaybetme" hatırlatmasının ne zaman çıkacağını
/// söyleyen sayaç ve bekleme kuralları (yan etkisi yalnız yerel tercihler).
///
/// Kurallar (ürün sahibi onayı, "önce oyna, hesabı sonra"):
///  * misafirin [triggerGames]. tamamlanmış oyununda (solo, yarışma, düello)
///    bir kez çıkar;
///  * her gösterimden sonra [cooldown] susar;
///  * toplam en çok [maxShows] kez çıkar.
/// Sayaç kullanıcı kimliğine bağlıdır: aynı cihazda başka bir misafir
/// hesabı önceki misafirin sayacını devralmaz.
class GuestSavePromptService {
  GuestSavePromptService._(this._prefs, this._uid, this._now);

  static const triggerGames = 3;
  static const maxShows = 3;
  static const cooldown = Duration(days: 7);

  final SharedPreferences? _prefs;
  final String _uid;
  final DateTime Function() _now;

  String get _gamesKey => 'zankurd.guestSave.$_uid.games';
  String get _showsKey => 'zankurd.guestSave.$_uid.shows';
  String get _lastKey => 'zankurd.guestSave.$_uid.lastShownMs';

  static Future<GuestSavePromptService> load(
    String userId, {
    DateTime Function()? now,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
    }
    return GuestSavePromptService._(prefs, userId, now ?? DateTime.now);
  }

  /// Bir oyun bitti: yalnız sayar (sayfayı göstermez, gösterimi kaydetmez).
  Future<void> countGame() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setInt(_gamesKey, (prefs.getInt(_gamesKey) ?? 0) + 1);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
    }
  }

  /// Sayaç ve bekleme kuralları sayfayı şimdi gösterir mi? Salt okuma.
  bool get isDue {
    final prefs = _prefs;
    if (prefs == null) return false;
    try {
      if ((prefs.getInt(_gamesKey) ?? 0) < triggerGames) return false;
      if ((prefs.getInt(_showsKey) ?? 0) >= maxShows) return false;
      final lastMs = prefs.getInt(_lastKey);
      return lastMs == null ||
          _now().difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) >=
              cooldown;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
      return false;
    }
  }

  /// Sayfa gösterildi: bekleme başlar (kullanıcı nasıl kapatırsa kapatsın).
  Future<void> markShown() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setInt(_showsKey, (prefs.getInt(_showsKey) ?? 0) + 1);
      await prefs.setInt(_lastKey, _now().millisecondsSinceEpoch);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
    }
  }

  /// Sayar ve şimdi gösterilmeli ise gösterimi kaydedip true döner.
  Future<bool> recordGame() async {
    await countGame();
    if (!isDue) return false;
    await markShown();
    return true;
  }
}

/// Oyun sonu ekranlarının çağırdığı giriş noktası. Oyunu ASLA engellemez:
/// hata, misafir olmama ya da sayaç dolmaması sessizce hiçbir şey yapmaz;
/// sayfa kapatılabilir ("Şimdi değil", kaydırma, dış dokunuş).
class GuestSavePrompt {
  const GuestSavePrompt._();

  /// Oyun BİTTİĞİ anda yalnız sayar; sayfayı göstermez. Sayaç ekrana değil
  /// oyuna bağlıdır: seviye atlatan ya da hemen kapatılan sonuç ekranı da
  /// oyunu düşürmez. Sonra [presentIfDue] çağrılır.
  static Future<GuestSavePromptService?> countGame(
    BuildContext context, {
    DateTime Function()? now,
  }) async {
    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isGuest) return null;
      final service = await GuestSavePromptService.load(
        auth.guestSaveUserId ?? 'local',
        now: now,
      );
      await service.countGame();
      return service;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
      return null;
    }
  }

  /// [countGame]in döndürdüğü servisle, kurallar izin veriyorsa sayfayı açar.
  static Future<void> presentIfDue(
    BuildContext context,
    GuestSavePromptService? service,
  ) async {
    try {
      if (service == null || !context.mounted || !service.isDue) return;
      await service.markShown();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const GuestSaveSheet(),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
    }
  }

  static Future<void> afterGame(
    BuildContext context, {
    DateTime Function()? now,
  }) async {
    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isGuest) return;
      final service = await GuestSavePromptService.load(
        auth.guestSaveUserId ?? 'local',
        now: now,
      );
      final show = await service.recordGame();
      if (!show || !context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const GuestSaveSheet(),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'guest_save_prompt');
    }
  }
}

class GuestSaveSheet extends StatefulWidget {
  const GuestSaveSheet({super.key});

  @override
  State<GuestSaveSheet> createState() => _GuestSaveSheetState();
}

class _GuestSaveSheetState extends State<GuestSaveSheet> {
  final _emailForm = GuestAccountEmailController();
  bool _busy = false;

  @override
  void dispose() {
    _emailForm.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Google/Apple bağlama: mevcut misafir kimliğini korur (linkIdentity),
  /// yeni oturum açmaz. Başarıda sayfa kapanır; OAuth tarayıcı akışında
  /// sonuç oturum dinleyicisinden gelir.
  Future<void> _link(Future<bool> Function(AuthProvider) run) async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final ok = await run(auth);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      navigator.pop();
    } else if (auth.errorMessage != null) {
      _toast(context.translateAuthError(auth.errorMessage!));
    }
  }

  Future<void> _saveWithEmail() async {
    if (!_emailForm.validate() || _busy) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    final ok = await auth.upgradeGuestAccount(
      email: _emailForm.email.text.trim(),
      password: _emailForm.password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      final msg = context.t(
        auth.needsEmailConfirmation ? K.accountCreated : K.accountSaved,
      );
      navigator.pop();
      messenger?.showSnackBar(SnackBar(content: Text(msg)));
    } else if (auth.errorMessage != null) {
      _toast(context.translateAuthError(auth.errorMessage!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SahneSpace.page,
          SahneSpace.page,
          SahneSpace.page,
          SahneSpace.page + bottom,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: t.s1, shape: SahneShape.l),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SahneSpace.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t(K.guestSaveTitle),
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
                const SizedBox(height: SahneSpace.x2),
                Text(
                  context.t(K.guestSaveBody),
                  style: SahneType.body.copyWith(color: t.tx2),
                ),
                const SizedBox(height: SahneSpace.x4),
                AuthSocialButtons(
                  linking: true,
                  onGoogle: _busy
                      ? null
                      : () => _link((a) => a.linkGoogleAccount()),
                  onApple: _busy
                      ? null
                      : () => _link((a) => a.linkAppleAccount()),
                ),
                const AuthEmailDivider(),
                GuestAccountEmailForm(controller: _emailForm, busy: _busy),
                const SizedBox(height: SahneSpace.x2),
                GuestAccountSaveButton(
                  controller: _emailForm,
                  busy: _busy,
                  onPressed: _saveWithEmail,
                ),
                const SizedBox(height: SahneSpace.x1),
                SahneButton.text(
                  label: context.t(K.guestSaveNotNow),
                  arrow: false,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
