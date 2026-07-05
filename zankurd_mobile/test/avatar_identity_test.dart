import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/avatar_presets.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';

void main() {
  group('AvatarIdentity', () {
    test('toJson/fromJson gidiş-dönüşü alanları korur', () {
      const identity = AvatarIdentity(
        iconId: 'tembur',
        colorHex: '#E94560',
        photoUrl: 'https://example.com/a.jpg',
        frameId: 'gold',
        showcaseTitle: 'Pispor · Ziman',
      );
      final restored = AvatarIdentity.fromJson(identity.toJson());
      expect(restored.iconId, 'tembur');
      expect(restored.colorHex, '#E94560');
      expect(restored.photoUrl, 'https://example.com/a.jpg');
      expect(restored.frameId, 'gold');
      expect(restored.showcaseTitle, 'Pispor · Ziman');
    });

    test('boş kimlik tüm alanları null tutar', () {
      const identity = AvatarIdentity();
      expect(identity.iconId, isNull);
      expect(identity.photoUrl, isNull);
      final restored = AvatarIdentity.fromJson(identity.toJson());
      expect(restored.showcaseTitle, isNull);
    });

    test('copyWith clearPhoto fotoğrafı null yapabilir', () {
      const identity = AvatarIdentity(photoUrl: 'x');
      expect(identity.copyWith(clearPhoto: true).photoUrl, isNull);
      expect(identity.copyWith().photoUrl, 'x');
    });
  });

  group('avatar presets', () {
    test('16 benzersiz ikon ve 8 benzersiz renk var', () {
      expect(avatarIcons.length, 16);
      expect(avatarIcons.keys.toSet().length, 16);
      expect(avatarColors.length, 8);
      expect(avatarColors.toSet().length, 8);
    });

    test('iconFor bilinen kimlikte ikon, bilinmeyende null döner', () {
      expect(iconFor('tembur'), isNotNull);
      expect(iconFor('olmayan_ikon'), isNull);
      expect(iconFor(null), isNull);
    });

    test('colorFrom geçerli hex çözer, bozukta fallback döner', () {
      expect(colorFrom('#E94560', fallback: Colors.black).value,
          const Color(0xFFE94560).value);
      expect(colorFrom('bozuk', fallback: Colors.black), Colors.black);
      expect(colorFrom(null, fallback: Colors.teal), Colors.teal);
    });
  });
}
