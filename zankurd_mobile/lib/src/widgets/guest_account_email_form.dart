import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Profil diyaloğu ve yarış alt sayfasının ortak alan/doğrulama durumu.
/// Sahibi, route kapanış animasyonu tamamlandığında bunu dispose eder.
class GuestAccountEmailController extends ChangeNotifier {
  GuestAccountEmailController() {
    email.addListener(notifyListeners);
    password.addListener(notifyListeners);
  }

  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();

  static bool validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  bool get canSubmit => validEmail(email.text) && password.text.length >= 6;
  bool validate() => canSubmit && (formKey.currentState?.validate() ?? false);

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }
}

class GuestAccountEmailForm extends StatefulWidget {
  const GuestAccountEmailForm({
    required this.controller,
    this.busy = false,
    super.key,
  });

  final GuestAccountEmailController controller;
  final bool busy;

  @override
  State<GuestAccountEmailForm> createState() => _GuestAccountEmailFormState();
}

class _GuestAccountEmailFormState extends State<GuestAccountEmailForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) => Form(
    key: widget.controller.formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneField(
          controller: widget.controller.email,
          enabled: !widget.busy,
          keyboardType: TextInputType.emailAddress,
          label: context.t(K.email),
          validator: (value) =>
              GuestAccountEmailController.validEmail(value ?? '')
              ? null
              : context.t(K.emailInvalid),
        ),
        const SizedBox(height: 12),
        SahneField(
          controller: widget.controller.password,
          enabled: !widget.busy,
          obscureText: _obscurePassword,
          suffixIcon: _obscurePassword ? AppIcons.eyeSlash : AppIcons.eye,
          suffixSemanticLabel: context.t(
            _obscurePassword ? K.showPassword : K.hidePassword,
          ),
          onSuffixIconPressed: widget.busy
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
          label: context.t(K.password),
          validator: (value) =>
              (value?.length ?? 0) >= 6 ? null : context.t(K.passwordTooShort),
        ),
        const SizedBox(height: SahneSpace.x2),
        Text(
          context.t(K.passwordHintMin6),
          style: SahneType.caption.copyWith(color: SahneTokens.of(context).tx2),
        ),
      ],
    ),
  );
}

/// Her iki yüzey de boş/geçersiz formu göndermeden aynı pasif durumu gösterir.
class GuestAccountSaveButton extends StatelessWidget {
  const GuestAccountSaveButton({
    required this.controller,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final GuestAccountEmailController controller;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => FilledButton(
      key: const ValueKey('guest-upgrade-save'),
      onPressed: busy || !controller.canSubmit
          ? null
          : () {
              if (controller.validate()) onPressed();
            },
      child: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SahneTokens.of(context).tx3,
              ),
            )
          : Text(context.t(K.save)),
    ),
  );
}
