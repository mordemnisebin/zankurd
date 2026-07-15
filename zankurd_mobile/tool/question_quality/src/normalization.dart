import 'dart:convert';
import 'dart:typed_data';

const _compositions = <String, String>{
  'A\u0302': 'Â',
  'a\u0302': 'â',
  'E\u0302': 'Ê',
  'e\u0302': 'ê',
  'I\u0302': 'Î',
  'i\u0302': 'î',
  'U\u0302': 'Û',
  'u\u0302': 'û',
  'S\u0327': 'Ş',
  's\u0327': 'ş',
  'C\u0327': 'Ç',
  'c\u0327': 'ç',
  'I\u0307': 'İ',
};

String normalizeUnicode(String value) {
  var result = value;
  for (final entry in _compositions.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

String _normalizeBase(String value) => normalizeUnicode(value)
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll(RegExp('[‘’´`]'), "'")
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\s\u00a0]+', unicode: true), ' ');

String normalizeText(String value) => _normalizeBase(
  value,
).replaceAll(RegExp(r'[.!?,;:]+$', unicode: true), '').trim();

String normalizeOption(String value) {
  final normalized = _normalizeBase(value);
  if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(normalized)) {
    return normalized;
  }
  return normalized.replaceAll(RegExp(r'[.!?,;:]+$', unicode: true), '').trim();
}

String normalizedQuestionFingerprint({
  required String prompt,
  required List<String> options,
  String? category,
}) {
  final normalizedOptions = options.map(normalizeOption).toList()..sort();
  return stableFingerprint(
    [
      normalizeText(prompt),
      normalizeText(category ?? ''),
      ...normalizedOptions,
    ].join('\u001f'),
  );
}

String stableFingerprint(String input) {
  const mask = 0xffffffffffffffff;
  int fnv(int seed) {
    var hash = seed;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & mask;
    }
    return hash.toUnsigned(64);
  }

  final left = fnv(0xcbf29ce484222325);
  final right = fnv(0x84222325cbf29ce4 ^ input.length);
  String hex64(int value) =>
      '${((value >>> 32) & 0xffffffff).toRadixString(16).padLeft(8, '0')}'
      '${(value & 0xffffffff).toRadixString(16).padLeft(8, '0')}';
  return '${hex64(left)}${hex64(right)}';
}

String sha256Hex(String input) {
  final bytes = Uint8List.fromList(utf8.encode(input));
  final bitLength = bytes.length * 8;
  final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLength)..setAll(0, bytes);
  padded[bytes.length] = 0x80;
  final data = ByteData.sublistView(padded);
  data.setUint64(paddedLength - 8, bitLength, Endian.big);

  var h0 = 0x6a09e667;
  var h1 = 0xbb67ae85;
  var h2 = 0x3c6ef372;
  var h3 = 0xa54ff53a;
  var h4 = 0x510e527f;
  var h5 = 0x9b05688c;
  var h6 = 0x1f83d9ab;
  var h7 = 0x5be0cd19;
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  int r(int value, int bits) =>
      ((value >>> bits) | (value << (32 - bits))) & 0xffffffff;
  int add(Iterable<int> values) =>
      values.fold<int>(0, (sum, value) => (sum + value) & 0xffffffff);

  for (var offset = 0; offset < paddedLength; offset += 64) {
    final w = List<int>.filled(64, 0);
    for (var i = 0; i < 16; i++) {
      w[i] = data.getUint32(offset + i * 4, Endian.big);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = r(w[i - 15], 7) ^ r(w[i - 15], 18) ^ (w[i - 15] >>> 3);
      final s1 = r(w[i - 2], 17) ^ r(w[i - 2], 19) ^ (w[i - 2] >>> 10);
      w[i] = add([w[i - 16], s0, w[i - 7], s1]);
    }
    var a = h0;
    var b = h1;
    var c = h2;
    var d = h3;
    var e = h4;
    var f = h5;
    var g = h6;
    var h = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = r(e, 6) ^ r(e, 11) ^ r(e, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = add([h, s1, ch, k[i], w[i]]);
      final s0 = r(a, 2) ^ r(a, 13) ^ r(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = add([s0, maj]);
      h = g;
      g = f;
      f = e;
      e = add([d, temp1]);
      d = c;
      c = b;
      b = a;
      a = add([temp1, temp2]);
    }
    h0 = add([h0, a]);
    h1 = add([h1, b]);
    h2 = add([h2, c]);
    h3 = add([h3, d]);
    h4 = add([h4, e]);
    h5 = add([h5, f]);
    h6 = add([h6, g]);
    h7 = add([h7, h]);
  }
  return [h0, h1, h2, h3, h4, h5, h6, h7]
      .map((value) => value.toUnsigned(32).toRadixString(16).padLeft(8, '0'))
      .join();
}
