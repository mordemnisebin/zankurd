import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 560;
              final wide = constraints.maxWidth >= 720;
              final wideCompact = compact && wide;
              final horizontalPadding = wide ? 32.0 : 20.0;
              final verticalPadding = compact ? 10.0 : 14.0;
              final headerHeight = compact
                  ? 130.0
                  : (constraints.maxHeight < 720 ? 150.0 : 220.0);
              final buttonMaxWidth = wide ? 520.0 : double.infinity;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  compact ? 12 : 20,
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
                                top: compact ? 0 : 28,
                                left: wideCompact ? 4 : 0,
                              ),
                              child: _AnimatedBrandLockup(
                                scale: _brandScale,
                                opacity: _brandOpacity,
                                logoWidth: compact ? 60 : 132,
                                showTagline: !wideCompact,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: TextButton(
                              onPressed: widget.onComplete,
                              child: Text(context.s('Derbas bike', 'Atla')),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: pages.length,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemBuilder: (context, index) => _OnboardingPage(
                          data: pages[index],
                          compact: compact,
                          wideCompact: wideCompact,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: i == _page ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppTheme.accent
                                  : AppTheme.borderColor(context),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: buttonMaxWidth),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: last
                              ? widget.onComplete
                              : () {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                          icon: Icon(
                            last
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            last
                                ? context.s('Dest pê bike', 'Başla')
                                : context.s('Piştî vê', 'Sonraki'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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
                  fontWeight: FontWeight.w700,
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
    final iconSize = compact ? 84.0 : 118.0;
    final iconGlyphSize = compact ? 36.0 : 48.0;
    final titleSize = compact ? 24.0 : 30.0;
    final bodySize = compact ? 14.0 : 16.0;
    final content = [
      _OnboardingIcon(data: data, size: iconSize, iconSize: iconGlyphSize),
      SizedBox(height: compact ? 16 : 28, width: wideCompact ? 24 : 0),
      Flexible(
        child: Column(
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
                fontWeight: FontWeight.w800,
                fontSize: titleSize,
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              data.body,
              textAlign: wideCompact ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSubColor(context),
                fontSize: bodySize,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wideCompact ? 720 : 440),
        child: wideCompact
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: content,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: content,
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
        color: data.color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: data.color.withValues(alpha: 0.35)),
      ),
      child: Icon(data.icon, color: data.color, size: iconSize),
    );
  }
}
