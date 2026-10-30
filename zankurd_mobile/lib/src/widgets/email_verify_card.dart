import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/email_verification.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Profildeki "E-postanı doğrula" kartı (nazik doğrulama).
///
/// Yalnız doğrulanmamış e-posta/parola hesabında görünür; Google/Apple ve
/// misafir hesapta ve durum bilinmiyorsa (çevrimdışı) HİÇ çizilmez: bilinmeyen
/// durumda kullanıcıyı rahatsız etmek yerine susar. Oyun ve sıralama bu karta
/// BAĞLI DEĞİLDİR.
///
/// Akış: düğme koda gönderir → alt sayfada e-postadaki kod girilir →
/// `verifyCode` + `markVerified`. Tekrar gönderme [resendCooldown] (60 sn)
/// bekler; sayfa kapatılıp kart yeniden dokunulsa da bekleme sürerken yeni
/// e-posta GİTMEZ, aynı sayfa açılır.
class EmailVerifyCard extends StatefulWidget {
  const EmailVerifyCard({
    required this.gateway,
    this.onVerified,
    this.resendCooldown = const Duration(seconds: 60),
    super.key,
  });

  final EmailVerificationGateway gateway;
  final VoidCallback? onVerified;
  final Duration resendCooldown;

  @override
  State<EmailVerifyCard> createState() => _EmailVerifyCardState();
}

class _EmailVerifyCardState extends State<EmailVerifyCard> {
  bool _visible = false;
  bool _sending = false;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!widget.gateway.needsVerification) return;
    final verified = await widget.gateway.isVerified();
    if (!mounted) return;
    // null = bilinmiyor: susar.
    if (verified == false) setState(() => _visible = true);
  }

  bool get _cooling {
    final sent = _lastSentAt;
    return sent != null &&
        DateTime.now().difference(sent) < widget.resendCooldown;
  }

  Future<void> _start() async {
    if (_sending) return;
    if (!_cooling) {
      setState(() => _sending = true);
      try {
        await widget.gateway.sendCode();
        _lastSentAt = DateTime.now();
      } on EmailVerificationException {
        if (!mounted) return;
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t(K.emailVerifySendFailed))),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _sending = false);
    }
    final verified = await showSahneSheet<bool>(
      context: context,
      title: context.t(K.emailVerifySheetTitle),
      builder: (sheetContext) => _CodeSheet(
        gateway: widget.gateway,
        resendCooldown: widget.resendCooldown,
        sentAt: _lastSentAt!,
        onResent: (at) => _lastSentAt = at,
      ),
    );
    if (verified == true && mounted) {
      setState(() => _visible = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.emailVerifyDone))));
      widget.onVerified?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x4),
      child: SahneSurfaceCard(
        key: const ValueKey('email-verify-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(AppIcons.envelope, size: 20, color: t.nilTx),
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    context.t(K.emailVerifyCardTitle),
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.emailVerifyCardBody),
              style: SahneType.body.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x3),
            SahneButton.secondary(
              buttonKey: const ValueKey('email-verify-send'),
              label: context.t(K.emailVerifyCardAction),
              icon: AppIcons.envelope,
              expand: true,
              loading: _sending,
              onPressed: _sending ? null : _start,
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({
    required this.gateway,
    required this.resendCooldown,
    required this.sentAt,
    required this.onResent,
  });

  final EmailVerificationGateway gateway;
  final Duration resendCooldown;
  final DateTime sentAt;
  final ValueChanged<DateTime> onResent;

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _controller = TextEditingController();
  Timer? _ticker;
  late DateTime _sentAt = widget.sentAt;
  int _secondsLeft = 0;
  bool _busy = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    final elapsed = DateTime.now().difference(_sentAt).inSeconds;
    _secondsLeft = (widget.resendCooldown.inSeconds - elapsed).clamp(
      0,
      widget.resendCooldown.inSeconds,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Geri sayım tik sayar (duvar saatine bakmaz): sayaç her saniye bir
  /// azalır, böylece sahte zamanlı testte de akar.
  void _tick() {
    if (_secondsLeft > 0 && mounted) setState(() => _secondsLeft -= 1);
  }

  Future<void> _resend() async {
    if (_busy || _secondsLeft > 0) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await widget.gateway.sendCode();
      _sentAt = DateTime.now();
      widget.onResent(_sentAt);
      if (mounted) {
        setState(() {
          _busy = false;
          _secondsLeft = widget.resendCooldown.inSeconds;
        });
      }
    } on EmailVerificationException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorKey = K.emailVerifySendFailed;
      });
    }
  }

  Future<void> _confirm() async {
    final code = _controller.text.trim();
    if (_busy || !isPlausibleEmailCode(code)) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await widget.gateway.verifyCode(code);
      final marked = await widget.gateway.markVerified();
      if (!mounted) return;
      if (marked) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _busy = false;
        _errorKey = K.emailVerifyGenericFailed;
      });
    } on EmailVerificationException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorKey = error.failure == EmailVerificationFailure.badCode
            ? K.emailVerifyWrongCode
            : K.emailVerifyGenericFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final canConfirm = !_busy && isPlausibleEmailCode(_controller.text.trim());
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + SahneSpace.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t(K.emailVerifySentTo, {
              'email': widget.gateway.email ?? '',
            }),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
          SahneField(
            key: const ValueKey('email-verify-code'),
            label: context.t(K.emailVerifyCodeLabel),
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => setState(() => _errorKey = null),
            onSubmitted: (_) => _confirm(),
          ),
          if (_errorKey != null) ...[
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(_errorKey!),
              key: const ValueKey('email-verify-error'),
              style: SahneType.captionStrong.copyWith(color: t.errTx),
            ),
          ],
          const SizedBox(height: SahneSpace.x3),
          SahneButton.primary(
            buttonKey: const ValueKey('email-verify-confirm'),
            label: context.t(K.emailVerifyConfirm),
            expand: true,
            arrow: false,
            loading: _busy,
            onPressed: canConfirm ? _confirm : null,
          ),
          const SizedBox(height: SahneSpace.x1),
          Align(
            alignment: Alignment.center,
            child: SahneButton.text(
              buttonKey: const ValueKey('email-verify-resend'),
              label: _secondsLeft > 0
                  ? context.t(K.emailVerifyResendIn, {
                      'seconds': groupThousands(_secondsLeft),
                    })
                  : context.t(K.emailVerifyResend),
              arrow: false,
              onPressed: (_busy || _secondsLeft > 0) ? null : _resend,
            ),
          ),
        ],
      ),
    );
  }
}
