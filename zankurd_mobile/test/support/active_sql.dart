/// SQL kaynağındaki YORUMLARI (`-- ...` ve `/* ... */`) atar, boşlukları
/// teke indirir ve küçük harfe çevirir.
///
/// Niçin: güvenlik sözleşmesi testleri ham metinde `contains` ararsa,
/// `revoke ...` satırı yoruma çevrildiğinde de geçer (GPT-6 Pro alan 8).
/// Eşleşme yalnız ETKİN SQL üzerinden yapılmalıdır.
String activeSql(String source) {
  var s = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
  s = s.replaceAll(RegExp(r'--[^\n]*'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
