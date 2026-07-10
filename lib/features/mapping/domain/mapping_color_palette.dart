import 'package:flutter/material.dart';

/// Colores persistentes por campo, asignados secuencialmente (§12.9).
const mappingFieldColors = <Color>[
  Color(0xFF4E79A7),
  Color(0xFFF28E2B),
  Color(0xFFE15759),
  Color(0xFF76B7B2),
  Color(0xFF59A14F),
  Color(0xFFEDC948),
  Color(0xFFB07AA1),
  Color(0xFFFF9DA7),
  Color(0xFF9C755F),
  Color(0xFFBAB0AC),
];

Color mappingColorForFieldIndex(int fieldIndex) {
  if (fieldIndex < 0) {
    return mappingFieldColors.first;
  }
  return mappingFieldColors[fieldIndex % mappingFieldColors.length];
}
