import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// Material / Cupertino / Widgets yerelleri.
///
/// Uygulama metinleri [Tr] tablosundadır; burası Flutter'ın KENDİ metinleridir
/// (düğmeler, saat seçici, kopyala/yapıştır çubuğu, ekran okuyucu etiketleri).
///
/// 1.2 (Pro denetimi 2026-11-05): `locale` sabit `tr` ve desteklenen liste
/// yalnız `tr` idi; Kurmancî seçilince saat seçicideki "Tamam / İptal / Saat
/// seçin" ve iOS'un "Kopyala / Yapıştır" çubuğu Türkçe kalıyordu. Flutter'da
/// Kurmancî (`ku`) yoktur; bu yüzden `ku` için Türkçe paketin ÜSTÜNE
/// Kurmancî metinleri bindiren üç temsilci yazıldı. Bindirilmeyen (nadir,
/// uygulamada görünmeyen) dizgeler AÇIKÇA SEÇİLMİŞ yedek olarak Türkçe
/// kalır — İngilizce değil: oyuncu zaten Türkçe okur, İngilizce okumaz.
/// Tarih/sayı biçimleri de `tr` biçimleridir (uygulama takvim göstermez;
/// saat seçici 24 saatlik).
class AppMaterialLocales {
  const AppMaterialLocales._();

  static const turkish = Locale('tr');
  static const kurmanji = Locale('ku');

  static Locale localeFor({required bool isKu}) => isKu ? kurmanji : turkish;

  static const supported = <Locale>[turkish, kurmanji];

  static const delegates = <LocalizationsDelegate<dynamic>>[
    // Önce Kurmancî temsilciler (yalnız `ku`yu destekler); `tr` düşüp
    // aşağıdaki resmî temsilcilere gider.
    _KuMaterialDelegate(),
    _KuCupertinoDelegate(),
    _KuWidgetsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}

/// Kurmancî Material metinleri. Jüri (Copilot + Gemini 3.8 Flash, 2026-11-05)
/// `timePickerInputHelpText` ve `openAppDrawerTooltip` için birbirinden farklı
/// öneriler verdi (uyuşmadı): bu ikisi bilerek EKLENMEDİ, Türkçe yedekte kalır.
/// Anahtarlar `MaterialLocalizations`
/// alıcılarının adıdır; testte her biri tek tek doğrulanır.
@visibleForTesting
const kKuMaterialStrings = <String, String>{
  'okButtonLabel': 'Temam',
  'cancelButtonLabel': 'Betal bike',
  'closeButtonLabel': 'Bigire',
  'closeButtonTooltip': 'Bigire',
  'backButtonTooltip': 'Vegere',
  'copyButtonLabel': 'Kopî bike',
  'cutButtonLabel': 'Bibire',
  'pasteButtonLabel': 'Pêve bike',
  'selectAllButtonLabel': 'Hemûyan hilbijêre',
  'clearButtonTooltip': 'Nivîsê paqij bike',
  'searchFieldLabel': 'Lê bigere',
  'lookUpButtonLabel': 'Lê bigere',
  'showMenuTooltip': 'Menuyê nîşan bide',
  'moreButtonTooltip': 'Zêdetir',
  'nextPageTooltip': 'Rûpela din',
  'previousPageTooltip': 'Rûpela berê',
  'modalBarrierDismissLabel': 'Bigire',
  'scrimLabel': 'qata tarî',
  'alertDialogLabel': 'Hişyarî',
  'dialogLabel': 'Qutiya diyalogê',
  'bottomSheetLabel': 'rûpela jêrîn',
  'timePickerHourLabel': 'Demjimêr',
  'timePickerMinuteLabel': 'Deqe',
  'timePickerDialHelpText': 'Demjimêrê hilbijêre',
  'timePickerHourModeAnnouncement': 'Demjimêrê hilbijêre',
  'timePickerMinuteModeAnnouncement': 'Deqeyê hilbijêre',
  'dialModeButtonLabel': 'Biçe moda hilbijêra dorveger',
  'inputTimeModeButtonLabel': 'Biçe moda têketina nivîsê',
  'anteMeridiemAbbreviation': 'BN',
  'postMeridiemAbbreviation': 'PN',
  'licensesPageTitle': 'Lîsans',
  'refreshIndicatorSemanticLabel': 'Nû bike',
  'shareButtonLabel': 'Parve bike',
  'deleteButtonTooltip': 'Jê bibe',
  'expandedIconTapHint': 'Teng bike',
  'collapsedIconTapHint': 'Fireh bike',
  'continueButtonLabel': 'Berdewam',
  'saveButtonLabel': 'Tomar bike',
};

/// Kurmancî Cupertino metinleri (iOS'ta metin seçme çubuğu bunları okur).
@visibleForTesting
const kKuCupertinoStrings = <String, String>{
  'alertDialogLabel': 'Hişyarî',
  'anteMeridiemAbbreviation': 'BN',
  'postMeridiemAbbreviation': 'PN',
  'backButtonLabel': 'Vegere',
  'cancelButtonLabel': 'Betal bike',
  'clearButtonLabel': 'Paqij bike',
  'copyButtonLabel': 'Kopî bike',
  'cutButtonLabel': 'Bibire',
  'pasteButtonLabel': 'Pêve bike',
  'selectAllButtonLabel': 'Hemûyan hilbijêre',
  'lookUpButtonLabel': 'Lê bigere',
  'searchWebButtonLabel': 'Li webê bigere',
  'shareButtonLabel': 'Parve bike',
  'modalBarrierDismissLabel': 'Bigire',
  'menuDismissLabel': 'Menuyê bigire',
  'searchTextFieldPlaceholderLabel': 'Lê bigere',
  'noSpellCheckReplacementsLabel': 'Peyva alternatîf nehat dîtin',
  'todayLabel': 'Îro',
};

class _KuMaterialLocalizations extends MaterialLocalizationTr {
  const _KuMaterialLocalizations({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  static const _s = kKuMaterialStrings;

  @override
  String get okButtonLabel => _s['okButtonLabel']!;
  @override
  String get cancelButtonLabel => _s['cancelButtonLabel']!;
  @override
  String get closeButtonLabel => _s['closeButtonLabel']!;
  @override
  String get closeButtonTooltip => _s['closeButtonTooltip']!;
  @override
  String get backButtonTooltip => _s['backButtonTooltip']!;
  @override
  String get copyButtonLabel => _s['copyButtonLabel']!;
  @override
  String get cutButtonLabel => _s['cutButtonLabel']!;
  @override
  String get pasteButtonLabel => _s['pasteButtonLabel']!;
  @override
  String get selectAllButtonLabel => _s['selectAllButtonLabel']!;
  @override
  String get clearButtonTooltip => _s['clearButtonTooltip']!;
  @override
  String get searchFieldLabel => _s['searchFieldLabel']!;
  @override
  String get lookUpButtonLabel => _s['lookUpButtonLabel']!;
  @override
  String get showMenuTooltip => _s['showMenuTooltip']!;
  @override
  String get moreButtonTooltip => _s['moreButtonTooltip']!;
  @override
  String get nextPageTooltip => _s['nextPageTooltip']!;
  @override
  String get previousPageTooltip => _s['previousPageTooltip']!;
  @override
  String get modalBarrierDismissLabel => _s['modalBarrierDismissLabel']!;
  @override
  String get scrimLabel => _s['scrimLabel']!;
  @override
  String get alertDialogLabel => _s['alertDialogLabel']!;
  @override
  String get dialogLabel => _s['dialogLabel']!;
  @override
  String get bottomSheetLabel => _s['bottomSheetLabel']!;
  @override
  String get timePickerHourLabel => _s['timePickerHourLabel']!;
  @override
  String get timePickerMinuteLabel => _s['timePickerMinuteLabel']!;
  @override
  String get timePickerDialHelpText => _s['timePickerDialHelpText']!;
  @override
  String get timePickerHourModeAnnouncement =>
      _s['timePickerHourModeAnnouncement']!;
  @override
  String get timePickerMinuteModeAnnouncement =>
      _s['timePickerMinuteModeAnnouncement']!;
  @override
  String get dialModeButtonLabel => _s['dialModeButtonLabel']!;
  @override
  String get inputTimeModeButtonLabel => _s['inputTimeModeButtonLabel']!;
  @override
  String get anteMeridiemAbbreviation => _s['anteMeridiemAbbreviation']!;
  @override
  String get postMeridiemAbbreviation => _s['postMeridiemAbbreviation']!;
  @override
  String get licensesPageTitle => _s['licensesPageTitle']!;
  @override
  String get refreshIndicatorSemanticLabel =>
      _s['refreshIndicatorSemanticLabel']!;
  @override
  String get shareButtonLabel => _s['shareButtonLabel']!;
  @override
  String get deleteButtonTooltip => _s['deleteButtonTooltip']!;
  @override
  String get expandedIconTapHint => _s['expandedIconTapHint']!;
  @override
  String get collapsedIconTapHint => _s['collapsedIconTapHint']!;
  @override
  String get continueButtonLabel => _s['continueButtonLabel']!;
  @override
  String get saveButtonLabel => _s['saveButtonLabel']!;
}

class _KuCupertinoLocalizations extends CupertinoLocalizationTr {
  const _KuCupertinoLocalizations({
    required super.fullYearFormat,
    required super.dayFormat,
    required super.weekdayFormat,
    required super.mediumDateFormat,
    required super.singleDigitHourFormat,
    required super.singleDigitMinuteFormat,
    required super.doubleDigitMinuteFormat,
    required super.singleDigitSecondFormat,
    required super.decimalFormat,
  });

  static const _s = kKuCupertinoStrings;

  @override
  String get alertDialogLabel => _s['alertDialogLabel']!;
  @override
  String get anteMeridiemAbbreviation => _s['anteMeridiemAbbreviation']!;
  @override
  String get postMeridiemAbbreviation => _s['postMeridiemAbbreviation']!;
  @override
  String get backButtonLabel => _s['backButtonLabel']!;
  @override
  String get cancelButtonLabel => _s['cancelButtonLabel']!;
  @override
  String get clearButtonLabel => _s['clearButtonLabel']!;
  @override
  String get copyButtonLabel => _s['copyButtonLabel']!;
  @override
  String get cutButtonLabel => _s['cutButtonLabel']!;
  @override
  String get pasteButtonLabel => _s['pasteButtonLabel']!;
  @override
  String get selectAllButtonLabel => _s['selectAllButtonLabel']!;
  @override
  String get lookUpButtonLabel => _s['lookUpButtonLabel']!;
  @override
  String get searchWebButtonLabel => _s['searchWebButtonLabel']!;
  @override
  String get shareButtonLabel => _s['shareButtonLabel']!;
  @override
  String get modalBarrierDismissLabel => _s['modalBarrierDismissLabel']!;
  @override
  String get menuDismissLabel => _s['menuDismissLabel']!;
  @override
  String get searchTextFieldPlaceholderLabel =>
      _s['searchTextFieldPlaceholderLabel']!;
  @override
  String get noSpellCheckReplacementsLabel =>
      _s['noSpellCheckReplacementsLabel']!;
  @override
  String get todayLabel => _s['todayLabel']!;
}

/// `tr` tarih verisinin yüklü olduğundan emin olur (resmî temsilci bunu
/// yükleme sırasında yapar) ve biçimleri o yerelden kurar.
Future<void> _ensureTrDateData() async {
  await GlobalMaterialLocalizations.delegate.load(AppMaterialLocales.turkish);
}

class _KuMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _KuMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    await _ensureTrDateData();
    const l = 'tr';
    return _KuMaterialLocalizations(
      fullYearFormat: intl.DateFormat.y(l),
      compactDateFormat: intl.DateFormat.yMd(l),
      shortDateFormat: intl.DateFormat.yMMMd(l),
      mediumDateFormat: intl.DateFormat.MMMEd(l),
      longDateFormat: intl.DateFormat.yMMMMEEEEd(l),
      yearMonthFormat: intl.DateFormat.yMMMM(l),
      shortMonthDayFormat: intl.DateFormat.MMMd(l),
      decimalFormat: intl.NumberFormat.decimalPattern(l),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', l),
    );
  }

  @override
  bool shouldReload(_KuMaterialDelegate old) => false;
}

class _KuCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KuCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    await _ensureTrDateData();
    const l = 'tr';
    return _KuCupertinoLocalizations(
      fullYearFormat: intl.DateFormat.y(l),
      dayFormat: intl.DateFormat.d(l),
      weekdayFormat: intl.DateFormat.E(l),
      mediumDateFormat: intl.DateFormat.MMMEd(l),
      singleDigitHourFormat: intl.DateFormat('HH', l),
      singleDigitMinuteFormat: intl.DateFormat.m(l),
      doubleDigitMinuteFormat: intl.DateFormat('mm', l),
      singleDigitSecondFormat: intl.DateFormat.s(l),
      decimalFormat: intl.NumberFormat.decimalPattern(l),
    );
  }

  @override
  bool shouldReload(_KuCupertinoDelegate old) => false;
}

/// Widgets yerelleştirmesi (metin yönü + "yeniden sırala" duyuruları):
/// Kurmancî soldan sağa yazılır; duyurular Türkçe yedekten gelir.
class _KuWidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _KuWidgetsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(const WidgetsLocalizationTr());

  @override
  bool shouldReload(_KuWidgetsDelegate old) => false;
}
