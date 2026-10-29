import 'dart:async';

import 'package:http/http.dart' as http;

/// Supabase'in REST/RPC/auth istekleri için süre sınırı koyan `http.Client`.
///
/// Varsayılan istemcide sınır yoktu: yarı kopuk ağda istek işletim sisteminin
/// soket zaman aşımına (dakikalar) dek asılı kalır, "kaydediliyor" düğmeleri
/// sonsuza dek kilitli dururdu. Sınırı aşan istek `TimeoutException` fırlatır;
/// mevcut hata yolları (`isLikelyOfflineError`) bunu zaten ağ hatası sayar.
/// Realtime websocket bu istemciyi kullanmaz.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient([http.Client? inner, this.timeoutFor = defaultTimeoutFor])
    : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration Function(Uri url) timeoutFor;

  static const apiTimeout = Duration(seconds: 15);
  static const functionTimeout = Duration(seconds: 30);
  static const uploadTimeout = Duration(seconds: 60);

  /// Depolama yüklemeleri (avatar fotoğrafı) uzun sürebilir; edge fonksiyonları
  /// orta; geri kalan her şey kısa sınırda.
  static Duration defaultTimeoutFor(Uri url) {
    final path = url.path;
    if (path.startsWith('/storage/v1/')) return uploadTimeout;
    if (path.startsWith('/functions/v1/')) return functionTimeout;
    return apiTimeout;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final limit = timeoutFor(request.url);
    final response = await _inner
        .send(request)
        .timeout(
          limit,
          onTimeout: () => throw TimeoutException(
            'Request timed out: ${request.method} ${request.url.path}',
            limit,
          ),
        );
    // Sınır yalnız BAŞLIKLARIN gelişine uygulanıyordu: başlıkları gelip
    // gövdesi yarıda takılan yanıt süresiz asılı kalıyordu (Codex denetimi
    // 2026-10-29). Gövdede de her parça arasında aynı sınır boşta kalma
    // süresi olarak işler; dolunca akış TimeoutException ile biter.
    return http.StreamedResponse(
      response.stream.timeout(
        limit,
        onTimeout: (sink) {
          sink.addError(
            TimeoutException(
              'Response body stalled: ${request.method} ${request.url.path}',
              limit,
            ),
          );
          sink.close();
        },
      ),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
