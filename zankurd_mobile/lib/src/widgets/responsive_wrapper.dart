import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  const ResponsiveWrapper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        // If the viewport width is wider than 600px, we restrict the layout to a centered 480px width
        final bool isWideScreen = width > 600;

        if (isWideScreen) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          final backdropBg = isDark ? const Color(0xFF05040B) : const Color(0xFFE5E3F1);
          final frameBg = isDark ? const Color(0xFF0F0C20) : const Color(0xFFF3F2F9);
          final borderCol = isDark ? const Color(0xFF2E2A52) : const Color(0xFFDDD9EC);

          return Scaffold(
            backgroundColor: backdropBg,
            body: Stack(
              children: [
                // Elegant background styling behind the centered mobile frame
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF080711), const Color(0xFF05040B)]
                            : [const Color(0xFFE5E3F1), const Color(0xFFF3F2F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: isDark ? 0.05 : 0.08,
                        child: Image.asset(
                          'assets/zankurd.webp',
                          width: 400,
                          height: 400,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.psychology,
                            size: 300,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Constrained and centered mobile frame
                Center(
                  child: Container(
                    width: 480,
                    height: height,
                    decoration: BoxDecoration(
                      color: frameBg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                          blurRadius: 40,
                          spreadRadius: 5,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.symmetric(
                        horizontal: BorderSide.none,
                        vertical: BorderSide(color: borderCol, width: 1.5),
                      ),
                    ),
                    child: child,
                  ),
                ),
              ],
            ),
          );
        }

        // Return direct child for standard mobile screens
        return child;
      },
    );
  }
}
