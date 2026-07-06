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
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppTheme.surface
        : AppTheme.lightSurface;

    final textStyle =
        widget.inputTextStyle ?? Theme.of(context).textTheme.bodyLarge;

    return ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            if (widget.label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
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
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.cardRadiusSmall),
                border: Border.all(
                  color: isFocused
                      ? AppTheme.primaryGradientStart
                      : AppTheme.borderColor(context).withValues(alpha: 0.5),
                  width: isFocused ? 1.5 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryGradientStart.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Prefix icon
                    if (widget.prefixIcon != null) ...[
                      Icon(
                        widget.prefixIcon,
                        size: 18,
                        color: isFocused
                            ? AppTheme.primaryGradientStart
                            : (isDarkMode
                                ? AppTheme.textMuted
                                : AppTheme.lightTextMuted),
                      ),
                      const SizedBox(width: 10),
                    ],
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardType: widget.keyboardType,
                        obscureText: widget.obscureText,
                        style: textStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor: AppTheme.primaryGradientStart,
                      ),
                    ),
                    // Suffix icon
                    if (widget.suffixIcon != null) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: widget.onSuffixIconPressed,
                        child: Icon(
                          widget.suffixIcon,
                          size: 18,
                          color: isFocused
                              ? AppTheme.primaryGradientStart
                              : (isDarkMode
                                  ? AppTheme.textMuted
                                  : AppTheme.lightTextMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
