import 'package:flutter/material.dart';

/// Creates a hexagonal clip path (6 vertices).
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(width * 0.5, 0);
    path.lineTo(width, height * 0.25);
    path.lineTo(width, height * 0.75);
    path.lineTo(width * 0.5, height);
    path.lineTo(0, height * 0.75);
    path.lineTo(0, height * 0.25);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(HexagonClipper oldClipper) => false;
}

/// Creates an octagonal clip path (8 vertices, 30% corner offset).
class OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final cornerOffset = 0.3; // 30% inset for octagon corners

    path.moveTo(width * cornerOffset, 0);
    path.lineTo(width * (1 - cornerOffset), 0);
    path.lineTo(width, height * cornerOffset);
    path.lineTo(width, height * (1 - cornerOffset));
    path.lineTo(width * (1 - cornerOffset), height);
    path.lineTo(width * cornerOffset, height);
    path.lineTo(0, height * (1 - cornerOffset));
    path.lineTo(0, height * cornerOffset);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(OctagonClipper oldClipper) => false;
}

/// Creates a diamond/rotated square clip path (4 vertices at 45° angles).
class DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(width * 0.5, 0);
    path.lineTo(width, height * 0.5);
    path.lineTo(width * 0.5, height);
    path.lineTo(0, height * 0.5);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(DiamondClipper oldClipper) => false;
}

/// Alias for DiamondClipper (same geometry, semantic distinction)
typedef RotatedSquareClipper = DiamondClipper;
