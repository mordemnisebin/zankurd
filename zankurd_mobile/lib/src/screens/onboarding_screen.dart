import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/styled_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;
  late final AnimationController _brandController;
  late final Animation<double> _brandScale;
  late final Animation<double> _brandOpacity;

  @override
  void initState() {
    super.initState();
    _brandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _brandScale = CurvedAnimation(
      parent: _brandController,
      curve: Curves.easeOutBack,
    );
    _brandOpacity = CurvedAnimation(
      parent: _brandController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages(context);
    final last = _page == pages.length - 1;
    final isDark = !AppTheme.isLight(context);

    final glowColor1 = isDark
        ? AppTheme.gold.withValues(alpha: 0.08)
        : AppTheme.gold.withValues(alpha: 0.05);
    final glowColor2 = isDark
        ? AppTheme.secondaryAccent.withValues(alpha: 0.12)
        : AppTheme.borderOf(context).withValues(alpha: 0.06);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor1, glowColor1.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -140,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor2, glowColor2.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 560;
                  final wide = constraints.maxWidth >= 720;
                  final wideCompact = compact && wide;
                  final horizontalPadding = wide ? 32.0 : 20.0;
                  final verticalPadding = compact ? 4.0 : 8.0;
                  final headerHeight = compact
                      ? 90.0
                      : (constraints.maxHeight < 720 ? 115.0 : 150.0);
                  final buttonMaxWidth = wide ? 520.0 : double.infinity;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      compact ? 10 : 12,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: headerHeight,
                          child: Stack(
                            children: [
                              Align(
                                alignment: wideCompact
                                    ? Alignment.centerLeft
                                    : Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: compact ? 0 : 8,
                                    left: wideCompact ? 4 : 0,
                                  ),
                                  child: _AnimatedBrandLockup(
                                    scale: _brandScale,
                                    opacity: _brandOpacity,
                                    logoWidth: compact ? 55 : 80,
                                    showTagline: !wideCompact,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: compact ? 0 : 2,
                                  ),
                                  child: TextButton(
                                    onPressed: widget.onComplete,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.textMutedColor(
                                        context,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      context.s('Derbas bike', 'Atla'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: pages.length,
                            onPageChanged: (value) =>
                                setState(() => _page = value),
                            itemBuilder: (context, index) => _OnboardingPage(
                              data: pages[index],
                              compact: compact,
                              wideCompact: wideCompact,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 6 : 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < pages.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeInOut,
                                width: i == _page ? 28 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: i == _page
                                      ? AppTheme.accentGradient
                                      : null,
                                  color: i == _page
                                      ? null
                                      : AppTheme.borderColor(
                                          context,
                                        ).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: i == _page
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.primaryGradientStart
                                                .withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: buttonMaxWidth),
                          child: SizedBox(
                            width: double.infinity,
                            child: GeometricGradientButton(
                              onPressed: last
                                  ? widget.onComplete
                                  : () {
                                      _controller.nextPage(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    },
                              icon: last
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              label: last
                                  ? context.s('Dest pê bike', 'Başla')
                                  : context.s('Piştî vê', 'Sonraki'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_OnboardingData> _pages(BuildContext context) {
    return [
      _OnboardingData(
        icon: Icons.menu_book_outlined,
        color: AppTheme.accent,
        title: context.s('Hîn bibe', 'Öğren'),
        body: context.s(
          'Kurmancî peyv, çand û zanînê bi pirsên kurt fêr bibe.',
          'Kurmancî kelimeleri, kültürü ve bilgiyi kısa sorularla öğren.',
        ),
      ),
      _OnboardingData(
        icon: Icons.emoji_events_outlined,
        color: AppTheme.gold,
        title: context.s('Pêşbirkê bike', 'Yarış'),
        body: context.s(
          'Bi hevalan an botan re pêşbirkê bike û pûanên xwe zêde bike.',
          'Arkadaşlarınla veya botlarla yarış, puanını yükselt.',
        ),
      ),
      _OnboardingData(
        icon: Icons.local_fire_department_outlined,
        color: AppTheme.violet,
        title: context.s('Her roj vegere', 'Günlük ödüller'),
        body: context.s(
          'Pêşbirka rojê, çerxa rojane û rozetan bi rêzê veke.',
          'Günün yarışması, günlük çark ve rozetlerle ilerle.',
        ),
      ),
    ];
  }
}

class _AnimatedBrandLockup extends StatelessWidget {
  const _AnimatedBrandLockup({
    required this.scale,
    required this.opacity,
    this.logoWidth = 132,
    this.showTagline = true,
  });

  final Animation<double> scale;
  final Animation<double> opacity;
  final double logoWidth;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(width: logoWidth, onCard: true),
            if (showTagline) ...[
              const SizedBox(height: 10),
              Text(
                context.s('Hîn bibe, pêş bike', 'Öğren, yarış, ilerle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.compact,
    required this.wideCompact,
  });

  final _OnboardingData data;
  final bool compact;
  final bool wideCompact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 70.0 : 96.0;
    final iconGlyphSize = compact ? 30.0 : 42.0;
    final titleSize = compact ? 20.0 : 26.0;
    final bodySize = compact ? 13.0 : 15.0;

    final textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: wideCompact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          data.title,
          textAlign: wideCompact ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w900,
            fontSize: titleSize,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          data.body,
          textAlign: wideCompact ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSubColor(context),
            fontSize: bodySize,
            height: 1.4,
          ),
        ),
      ],
    );

    final content = [
      _OnboardingIcon(data: data, size: iconSize, iconSize: iconGlyphSize),
      SizedBox(height: compact ? 10 : 18, width: wideCompact ? 20 : 0),
      if (wideCompact) Flexible(child: textColumn) else textColumn,
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wideCompact ? 720 : 440),
        child: wideCompact
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: content,
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: content,
                ),
              ),
      ),
    );
  }
}

class _OnboardingIcon extends StatelessWidget {
  const _OnboardingIcon({
    required this.data,
    required this.size,
    required this.iconSize,
  });

  final _OnboardingData data;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.color.withValues(alpha: 0.22),
            data.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: data.color.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Center(
        child: Icon(data.icon, color: data.color, size: iconSize),
      ),
    );
  }
}
