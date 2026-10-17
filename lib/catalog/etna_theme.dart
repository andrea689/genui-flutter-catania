import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../domain/seismic_event.dart';

/// The palette, shared with the talk slides (`slides/css/theme-etna.css`).
///
/// Exactly the same values: the demo and the deck must look like one thing.
abstract final class EtnaPalette {
  /// Deep black. Page background.
  static const ink0 = Color(0xFF06060A);

  /// Content area background.
  static const ink1 = Color(0xFF0E0E13);

  /// Panel: **this is the card color**, and it must stand out from [ink1].
  static const ink2 = Color(0xFF17171F);

  /// Raised panel.
  static const ink3 = Color(0xFF21212C);

  /// Borders.
  static const line = Color(0xFF3E3E4D);

  static const text = Color(0xFFF7F3ED);
  static const lava = Color(0xFFFF4A21);
  static const lavaHi = Color(0xFFFF7A52);
  static const lavaLo = Color(0xFFB32407);
  static const ocra = Color(0xFFF2B33D);
  static const ocraLo = Color(0xFF8A5F12);

  /// Ash: secondary text and decorations. Never for body text.
  static const ash = Color(0xFF7E8AA0);
  static const ok = Color(0xFF4FD69C);

  // Light theme: warm stone, not pink. A red seed passed to
  // ColorScheme.fromSeed tints every surface pink, which is exactly the
  // effect to avoid.
  static const stone0 = Color(0xFFFBF8F4);
  static const stone1 = Color(0xFFFFFFFF);
  static const stone2 = Color(0xFFF1EBE2);
  static const stoneLine = Color(0xFFD8D0C4);
  static const inkText = Color(0xFF1A1A22);
}

/// The app's two themes.
///
/// Built by hand, **not** with `ColorScheme.fromSeed`: from a red seed
/// Material 3 derives pinkish surfaces, and the cards end up barely
/// distinguishable from the background. Here the step between page background
/// and card background is explicit, and every card also has a border: on a
/// poor projector elevation is invisible, a border isn't.
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
    // Explicit font: without it each platform uses its own (SF on Apple,
    // Roboto downloaded at runtime on web) and the app and the previewer
    // diverge.
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      cardTheme: CardThemeData(
        color: card,
        // Zero elevation: on a projector the shadow disappears. The border
        // doesn't.
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

/// The theme for the catalog's `@Preview`s: `theme: etnaPreviewTheme`.
///
/// Without it, a preview inherits the previewer's own theme (the DevTools one:
/// 12 px text, borderless cards, its own colors) and the card doesn't look
/// like the one in the app.
PreviewThemeData etnaPreviewTheme() => const _EtnaPreviewTheme();

final class _EtnaPreviewTheme extends PreviewThemeData {
  const _EtnaPreviewTheme();

  /// In the previewer the app is imported as a package, and its fonts are
  /// named `packages/<package>/<family>`. Plain `Roboto` doesn't exist there:
  /// Flutter Web would download it from fonts.gstatic.com, regular weight
  /// only.
  static const _fontFamily = 'packages/genui_flutter_catania/Roboto';

  @override
  Widget apply(BuildContext context, Widget child) {
    // The previewer puts the preview's brightness (annotation or toggle) in
    // the MediaQuery, not in the theme.
    final base = MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? EtnaTheme.dark
        : EtnaTheme.light;
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: _fontFamily),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),
      ),
      // Text with no explicit style takes its DefaultTextStyle from here, not
      // from the previewer's.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Visual language shared by the catalog cards.
///
/// It lives here rather than inside the widgets because consistency across
/// cards is exactly what makes an AI-composed UI believable: different pieces,
/// picked at runtime, must look like they were made together.
extension SeismicSeverityStyle on SeismicSeverity {
  /// Color of the magnitude band, adapted to the light or dark theme.
  /// It gets warmer as magnitude grows: ash, green, ochre, lava.
  /// They're the same accents as the slides, so the audience reads them the
  /// same way.
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

  /// Human-readable label for the band.
  String get label => switch (this) {
    SeismicSeverity.micro => 'Microsismicità',
    SeismicSeverity.light => 'Lieve',
    SeismicSeverity.moderate => 'Moderata',
    SeismicSeverity.strong => 'Forte',
  };
}

/// Formats a UTC instant in Italian time, in compact form.
///
/// Deliberately without `intl`: the previewer runs on Flutter Web without
/// locale initialization, and one less dependency in the pure widget is one
/// less thing that can break live.
String formatEtnaTime(DateTime utc) {
  final local = utc.add(const Duration(hours: 2));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Date only, for axes and groupings.
String formatEtnaDate(DateTime utc) {
  final local = utc.add(const Duration(hours: 2));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}';
}
