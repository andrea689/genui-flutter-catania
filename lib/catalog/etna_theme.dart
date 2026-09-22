import 'package:flutter/material.dart';

import '../domain/seismic_event.dart';

/// Linguaggio visivo condiviso dalle card del catalogo.
///
/// Sta qui e non dentro i widget perche' la coerenza fra le card e' proprio
/// cio' che rende credibile una UI composta dall'AI: pezzi diversi, scelti a
/// runtime, devono sembrare nati insieme.
extension SeismicSeverityStyle on SeismicSeverity {
  /// Colore della fascia di magnitudo, adattato al tema chiaro o scuro.
  Color color(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      SeismicSeverity.micro =>
        dark ? const Color(0xFF7FB3D5) : const Color(0xFF3E7CB1),
      SeismicSeverity.light =>
        dark ? const Color(0xFF7DCFB6) : const Color(0xFF2A9D8F),
      SeismicSeverity.moderate =>
        dark ? const Color(0xFFF4C36B) : const Color(0xFFE08D2F),
      SeismicSeverity.strong =>
        dark ? const Color(0xFFF08B7E) : const Color(0xFFD1495B),
    };
  }

  /// Etichetta leggibile della fascia.
  String get label => switch (this) {
    SeismicSeverity.micro => 'Microsismicita',
    SeismicSeverity.light => 'Lieve',
    SeismicSeverity.moderate => 'Moderata',
    SeismicSeverity.strong => 'Forte',
  };
}

/// Formatta un istante UTC nel fuso italiano, in forma compatta.
///
/// Volutamente senza `intl`: il previewer gira su Flutter Web senza
/// inizializzazione delle locale, e una dipendenza in meno nel widget puro
/// e' una cosa in meno che puo' rompersi dal vivo.
String formatEtnaTime(DateTime utc) {
  final local = utc.add(const Duration(hours: 2));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Solo la data, per gli assi e i raggruppamenti.
String formatEtnaDate(DateTime utc) {
  final local = utc.add(const Duration(hours: 2));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}';
}
