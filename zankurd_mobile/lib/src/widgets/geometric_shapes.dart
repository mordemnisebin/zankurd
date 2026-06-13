import 'package:flutter/material.dart';

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

class OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final offset = 0.3;

    path.moveTo(width * offset, 0);
    path.lineTo(width * (1 - offset), 0);
    path.lineTo(width, height * offset);
    path.lineTo(width, height * (1 - offset));
    path.lineTo(width * (1 - offset), height);
    path.lineTo(width * offset, height);
    path.lineTo(0, height * (1 - offset));
    path.lineTo(0, height * offset);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(OctagonClipper oldClipper) => false;
}

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

class RotatedSquareClipper extends CustomClipper<Path> {
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
  bool shouldReclip(RotatedSquareClipper oldClipper) => false;
}
