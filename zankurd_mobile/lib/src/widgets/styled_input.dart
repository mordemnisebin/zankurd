import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StyledInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final String? Function(String?)? validator;
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
    this.validator,
    this.labelStyle,
    this.inputTextStyle,
  });

  @override
  State<StyledInputField> createState() => _StyledInputFieldState();
}

class _StyledInputFieldState extends State<StyledInputField> {
  late FocusNode _focusNode;
  late ValueNotifier<bool> _isFocused;
  String? _errorText;

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
    // Focus kazanınca eski hata temizlenir (yeniden yazmaya başlayınca).
    if (!_focusNode.hasFocus && widget.validator != null) {
      _validate(widget.controller.text);
    }
  }

  void _validate(String value) {
    if (widget.validator == null) return;
    final error = widget.validator!(value);
    if (error != _errorText) {
      setState(() => _errorText = error);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
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
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardType: widget.keyboardType,
                        obscureText: widget.obscureText,
                        style: textStyle,
                        onChanged: (value) => _validate(value),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor: hasError
                            ? AppTheme.wrong
                            : AppColors.focus,
                      ),
                    ),
                    // Suffix icon
                    if (widget.suffixIcon != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      GestureDetector(
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
