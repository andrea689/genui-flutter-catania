import 'package:flutter/material.dart';

import '../domain/seismic_event.dart';

/// La palette, condivisa con le slide del talk (`slides/css/theme-etna.css`).
///
/// Stessi valori esatti: demo e deck devono sembrare la stessa cosa.
abstract final class EtnaPalette {
  /// Nero profondo. Sfondo della pagina.
  static const ink0 = Color(0xFF06060A);

  /// Sfondo delle aree di contenuto.
  static const ink1 = Color(0xFF0E0E13);

  /// Pannello: **e' il colore delle card**, e deve staccare da [ink1].
  static const ink2 = Color(0xFF17171F);

  /// Pannello in rilievo.
  static const ink3 = Color(0xFF21212C);

  /// Bordi.
  static const line = Color(0xFF3E3E4D);

  static const text = Color(0xFFF7F3ED);
  static const lava = Color(0xFFFF4A21);
  static const lavaHi = Color(0xFFFF7A52);
  static const lavaLo = Color(0xFFB32407);
  static const ocra = Color(0xFFF2B33D);
  static const ocraLo = Color(0xFF8A5F12);

  /// Cenere: testo secondario e decorazioni. Mai per il corpo.
  static const ash = Color(0xFF7E8AA0);
  static const ok = Color(0xFF4FD69C);

  // Tema chiaro: pietra calda, non rosa. Un seme rosso passato a
  // ColorScheme.fromSeed tinge di rosa ogni superficie, ed e' esattamente
  // l'effetto da evitare.
  static const stone0 = Color(0xFFFBF8F4);
  static const stone1 = Color(0xFFFFFFFF);
  static const stone2 = Color(0xFFF1EBE2);
  static const stoneLine = Color(0xFFD8D0C4);
  static const inkText = Color(0xFF1A1A22);
}

/// I due temi dell'app.
///
/// Costruiti a mano, **non** con `ColorScheme.fromSeed`: da un seme rosso
/// Material 3 deriva superfici rosate, e le card finiscono a un soffio dallo
/// sfondo. Qui il salto fra sfondo pagina e sfondo card e' esplicito, e ogni
/// card ha anche un bordo: su un proiettore scadente l'elevazione non si vede,
/// il bordo si'.
abstract final class EtnaTheme {
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: EtnaPalette.lavaHi,
      onPrimary: Color(0xFF2B0A02),
      primaryContainer: EtnaPalette.lavaLo,
      onPrimaryContainer: EtnaPalette.text,
      secondary: EtnaPalette.ocra,
      onSecondary: Color(0xFF2B1D02),
      tertiary: EtnaPalette.ash,
      onTertiary: EtnaPalette.ink0,
      error: Color(0xFFFF8A80),
      onError: Color(0xFF2B0A02),
      surface: EtnaPalette.ink1,
      onSurface: EtnaPalette.text,
      surfaceContainerLowest: EtnaPalette.ink0,
      surfaceContainerLow: EtnaPalette.ink1,
      surfaceContainer: EtnaPalette.ink2,
      surfaceContainerHigh: EtnaPalette.ink3,
      surfaceContainerHighest: EtnaPalette.ink3,
      onSurfaceVariant: EtnaPalette.ash,
      outline: EtnaPalette.line,
      outlineVariant: EtnaPalette.line,
    ),
    scaffold: EtnaPalette.ink0,
    card: EtnaPalette.ink2,
    border: EtnaPalette.line,
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: EtnaPalette.lavaLo,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFDBD1),
      onPrimaryContainer: Color(0xFF3B0A00),
      secondary: EtnaPalette.ocraLo,
      onSecondary: Colors.white,
      tertiary: Color(0xFF4A5568),
      onTertiary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: EtnaPalette.stone0,
      onSurface: EtnaPalette.inkText,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: EtnaPalette.stone1,
      surfaceContainer: EtnaPalette.stone1,
      surfaceContainerHigh: EtnaPalette.stone2,
      surfaceContainerHighest: EtnaPalette.stone2,
      onSurfaceVariant: Color(0xFF5A5A66),
      outline: EtnaPalette.stoneLine,
      outlineVariant: EtnaPalette.stoneLine,
    ),
    scaffold: EtnaPalette.stone0,
    card: EtnaPalette.stone1,
    border: EtnaPalette.stoneLine,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color border,
  }) {
    final base = ThemeData(brightness: brightness, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      cardTheme: CardThemeData(
        color: card,
        // Elevazione zero: su un proiettore l'ombra sparisce. Il bordo no.
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Linguaggio visivo condiviso dalle card del catalogo.
///
/// Sta qui e non dentro i widget perche' la coerenza fra le card e' proprio
/// cio' che rende credibile una UI composta dall'AI: pezzi diversi, scelti a
/// runtime, devono sembrare nati insieme.
extension SeismicSeverityStyle on SeismicSeverity {
  /// Colore della fascia di magnitudo, adattato al tema chiaro o scuro.
  /// Sale di temperatura con la magnitudo: cenere, verde, ocra, lava.
  /// Sono gli stessi accenti delle slide, cosi' il pubblico li rilegge uguali.
  Color color(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      SeismicSeverity.micro =>
        dark ? EtnaPalette.ash : const Color(0xFF4A5568),
      SeismicSeverity.light =>
        dark ? EtnaPalette.ok : const Color(0xFF1B7F5A),
      SeismicSeverity.moderate =>
        dark ? EtnaPalette.ocra : EtnaPalette.ocraLo,
      SeismicSeverity.strong =>
        dark ? EtnaPalette.lavaHi : EtnaPalette.lavaLo,
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
