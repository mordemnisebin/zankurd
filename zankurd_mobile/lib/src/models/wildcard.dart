import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

enum WildcardType { fiftyFifty, audience, doubleAnswer, changeQuestion }

extension WildcardTypeDetails on WildcardType {
  int get coinCost => switch (this) {
    WildcardType.fiftyFifty => 20,
    WildcardType.audience => 30,
    WildcardType.doubleAnswer => 50,
    WildcardType.changeQuestion => 40,
  };

  IconData get icon => switch (this) {
    WildcardType.fiftyFifty => AppIcons.wandMagicSparkles,
    WildcardType.audience => AppIcons.peopleGroup,
    WildcardType.doubleAnswer => AppIcons.circleCheck,
    WildcardType.changeQuestion => AppIcons.arrowsRotate,
  };

  String label(bool isKu) => switch (this) {
    WildcardType.fiftyFifty => Tr.forKu(K.metin, isKu),
    WildcardType.audience => Tr.forKu(K.sikIpucu, isKu),
    WildcardType.doubleAnswer => Tr.forKu(K.ciftCevap, isKu),
    WildcardType.changeQuestion => Tr.forKu(K.soruDegistir, isKu),
  };

  /// 2026-07-24 canlı denetim: jokerler dört neon renk (kehribar, zümrüt,
  /// neon yeşil, elektrik moru) taşıyordu ve quiz ekranının en gürültülü
  /// öğesi onlardı — göz soruya değil alt bara gidiyordu. Tonlar Zanîn
  /// paletinin nötr bandına çekildi; joker yardımcı araçtır, kahraman değil.
  Color get themeColor => switch (this) {
    WildcardType.fiftyFifty => AppTheme.gold,
    WildcardType.audience => AppTheme.playCyan,
    WildcardType.doubleAnswer => AppTheme.playGreen,
    WildcardType.changeQuestion => AppTheme.playPurple,
  };
}

class WildcardState {
  const WildcardState({
    this.fiftyFiftyUsed = false,
    this.audienceUsed = false,
    this.doubleAnswerActivated = false,
    this.changeQuestionUsed = false,
  });

  final bool fiftyFiftyUsed;
  final bool audienceUsed;
  final bool doubleAnswerActivated;
  final bool changeQuestionUsed;

  bool isUsed(WildcardType type) => switch (type) {
    WildcardType.fiftyFifty => fiftyFiftyUsed,
    WildcardType.audience => audienceUsed,
    WildcardType.doubleAnswer => doubleAnswerActivated,
    WildcardType.changeQuestion => changeQuestionUsed,
  };

  WildcardState copyWith({
    bool? fiftyFiftyUsed,
    bool? audienceUsed,
    bool? doubleAnswerActivated,
    bool? changeQuestionUsed,
  }) => WildcardState(
    fiftyFiftyUsed: fiftyFiftyUsed ?? this.fiftyFiftyUsed,
    audienceUsed: audienceUsed ?? this.audienceUsed,
    doubleAnswerActivated: doubleAnswerActivated ?? this.doubleAnswerActivated,
    changeQuestionUsed: changeQuestionUsed ?? this.changeQuestionUsed,
  );

  WildcardState resetForNextQuestion() => const WildcardState();
}
