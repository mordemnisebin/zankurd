import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';

/// [BuildContext] üzerinden [ZanKurdRepository]'ye kolay erişim.
///
/// Kullanım:
/// ```dart
/// final repo = context.repo;
/// await repo.loadCoinBalance();
/// ```
///
/// Bu extension, prop-drilling'i (constructor üzerinden repository geçirme)
/// kademeli olarak kaldırmak için temel sağlar. Yeni kodda `widget.repository`
/// yerine `context.repo` tercih edilmelidir.
extension ZanKurdRepo on BuildContext {
  /// Mevcut [ZanKurdRepository] örneğini döndürür.
  ///
  /// [ProviderNotFoundException] fırlatır eğer ağaçta
  /// `Provider<ZanKurdRepository>` bulunamazsa (örn. test mount'u eksikse).
  ZanKurdRepository get repo => read<ZanKurdRepository>();
}
