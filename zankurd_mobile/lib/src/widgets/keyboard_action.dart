import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sahne/sahne.dart';

/// Dokunma ve semantik eylemi olan kartlara klavye odağı ekler.
/// İç düğmeler kendi eylemlerini ve Tab duraklarını korur.
class KeyboardAction extends StatefulWidget {
  const KeyboardAction({
    required this.onActivate,
    required this.child,
    super.key,
  });

  final VoidCallback? onActivate;
  final Widget child;

  @override
  State<KeyboardAction> createState() => _KeyboardActionState();
}

class _KeyboardActionState extends State<KeyboardAction> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.onActivate != null,
    onShowFocusHighlight: (value) => setState(() => _showFocus = value),
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onActivate?.call();
          return null;
        },
      ),
    },
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: _showFocus && widget.onActivate != null
            ? Border.all(color: SahneTokens.of(context).tx, width: SahneRing.r2)
            : null,
      ),
      child: widget.child,
    ),
  );
}
