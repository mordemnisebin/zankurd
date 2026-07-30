import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Stil uygulanmış giriş alanı.
///
/// `validator` + `autovalidateMode` ile Form olmadan da inline hata
/// gösterebilir.  Form ile birlikte kullanıldığında `GlobalKey` üzerinden
/// `validate()` çağrısı yapılabilir (2026-07-22 canlı UX denetimi: inline doğrulama).
class StyledInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final String? suffixSemanticLabel;
  final String? Function(String?)? validator;

  /// Ne zaman otomatik doğrulama yapılacağını belirler.
  /// `disabled` → yalnız `validate()` çağrıldığında doğrular.
  /// `onUserInteraction` → kullanıcı yazmaya başladıktan sonra her değişiklikte doğrular.
  final AutovalidateMode autovalidateMode;

  /// Alan boşken arka planda görünen ipucu metni.
  final String? hintText;

  final TextStyle? labelStyle;
  final TextStyle? inputTextStyle;

  const StyledInputField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.suffixSemanticLabel,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.hintText,
    this.labelStyle,
    this.inputTextStyle,
  });

  @override
  State<StyledInputField> createState() => StyledInputFieldState();
}

class StyledInputFieldState extends State<StyledInputField> {
  late FocusNode _focusNode;
  late ValueNotifier<bool> _isFocused;
  String? _errorText;
  // Kullanıcı alana en az bir kez etkileşimde bulundu mu?
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _isFocused = ValueNotifier(false);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _isFocused.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    _isFocused.value = _focusNode.hasFocus;
    // Kullanıcı alana girdi ve ayrıldı → etkileşim sayılır.
    if (!_focusNode.hasFocus) {
      _hasInteracted = true;
      if (_shouldAutoValidate()) {
        _runValidation(widget.controller.text);
      }
    }
  }

  bool _shouldAutoValidate() {
    switch (widget.autovalidateMode) {
      case AutovalidateMode.always:
        return true;
      case AutovalidateMode.onUserInteraction:
        return _hasInteracted;
      case AutovalidateMode.onUserInteractionIfError:
        // İlk etkileşimden sonra yalnız mevcut hata varsa güncelle.
        return _hasInteracted && _errorText != null;
      case AutovalidateMode.onUnfocus:
        // Focus kaybedildikten sonra doğrula (_handleFocusChange tetikler).
        return _hasInteracted && !_focusNode.hasFocus;
      case AutovalidateMode.disabled:
        return false;
    }
  }

  void _onChanged(String value) {
    _hasInteracted = true;
    if (_shouldAutoValidate()) {
      _runValidation(value);
    }
  }

  void _runValidation(String value) {
    if (widget.validator == null) return;
    final error = widget.validator!(value);
    if (error != _errorText) {
      setState(() => _errorText = error);
    }
  }

  /// Doğrulamayı zorla çalıştırır ve sonucu döndürür.
  /// `Form.validate()` ile birlikte kullanmak için public API.
  bool validate() {
    _hasInteracted = true;
    _runValidation(widget.controller.text);
    return _errorText == null;
  }

  /// Mevcut hata metnini temizler.
  void clearError() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle =
        widget.inputTextStyle ?? Theme.of(context).textTheme.bodyLarge;
    final hasError = _errorText != null;

    return ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, _) {
        final borderColor = hasError
            ? AppTheme.wrong
            : isFocused
            ? AppColors.focus
            : AppTheme.borderColor(context).withValues(alpha: 0.5);
        final borderWidth = (hasError || isFocused) ? 1.5 : 1.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            if (widget.label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  widget.label,
                  style:
                      widget.labelStyle ??
                      Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            // Input field
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: (hasError || isFocused)
                    ? AppShadows.focusRing(borderColor)
                    : [],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: widget.suffixIcon == null ? 14 : 4,
                ),
                child: Row(
                  children: [
                    // Prefix icon
                    if (widget.prefixIcon != null) ...[
                      Icon(
                        widget.prefixIcon,
                        size: 18,
                        color: hasError
                            ? AppTheme.wrong
                            : isFocused
                            ? AppColors.focus
                            : AppTheme.textMutedColor(context),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    // Text field
                    Expanded(
                      child: Semantics(
                        label: widget.label.isEmpty ? null : widget.label,
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          keyboardType: widget.keyboardType,
                          obscureText: widget.obscureText,
                          style: textStyle,
                          onChanged: _onChanged,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            hintText: widget.hintText ?? '',
                            hintStyle: TextStyle(
                              color: AppTheme.textMutedColor(context),
                              fontSize: 14,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          cursorColor: hasError
                              ? AppTheme.wrong
                              : AppColors.focus,
                        ),
                      ),
                    ),
                    // Suffix icon
                    if (widget.suffixIcon != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Semantics(
                        label: widget.suffixSemanticLabel,
                        button: widget.onSuffixIconPressed != null,
                        enabled: widget.onSuffixIconPressed != null,
                        onTap: widget.onSuffixIconPressed,
                        child: ExcludeSemantics(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onSuffixIconPressed,
                              child: Icon(
                                widget.suffixIcon,
                                size: 18,
                                color: hasError
                                    ? AppTheme.wrong
                                    : isFocused
                                    ? AppColors.focus
                                    : AppTheme.textMutedColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Error text
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _errorText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.wrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
