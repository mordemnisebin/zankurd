import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Material widget yerelleri. Uygulama metinleri [Tr] tablosundadır;
/// time picker ve dialog düğmeleri Türkçe Material paketiyle gelir.
/// Kurmancî Material tam olmadığı için ku oturumunda da `tr` kullanılır.
class AppMaterialLocales {
  const AppMaterialLocales._();

  static const supported = <Locale>[Locale('tr')];

  static const delegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
