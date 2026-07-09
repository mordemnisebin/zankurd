import 'package:flutter/material.dart';

enum WildcardType { fiftyFifty, audience, doubleAnswer, changeQuestion }

extension WildcardTypeDetails on WildcardType {
  int get coinCost => switch (this) {
    WildcardType.fiftyFifty => 20,
    WildcardType.audience => 30,
    WildcardType.doubleAnswer => 50,
    WildcardType.changeQuestion => 40,
  };

  IconData get icon => switch (this) {
    WildcardType.fiftyFifty => Icons.auto_awesome_outlined,
    WildcardType.audience => Icons.groups_outlined,
    WildcardType.doubleAnswer => Icons.check_circle_outline,
    WildcardType.changeQuestion => Icons.refresh_outlined,
  };

  String label(bool isKu) => switch (this) {
    WildcardType.fiftyFifty => isKu ? 'Nîv bi Nîv' : '50/50',
    WildcardType.audience => isKu ? 'Ji Temaşevanan' : 'Seyirciye Sor',
    WildcardType.doubleAnswer => isKu ? 'Du Bersiv' : 'Çift Cevap',
    WildcardType.changeQuestion => isKu ? 'Pirsê Biguhere' : 'Soru Değiştir',
  };

  Color get themeColor => switch (this) {
    WildcardType.fiftyFifty => const Color(0xFFFFB300), // Altın
    WildcardType.audience => const Color(0xFF00BFA5), // Zümrüt yeşil
    WildcardType.doubleAnswer => const Color(0xFF00C853), // Neon yeşil
    WildcardType.changeQuestion => const Color(0xFF7C4DFF), // Derin mor
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
