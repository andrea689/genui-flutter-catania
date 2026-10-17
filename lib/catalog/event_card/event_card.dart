import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../domain/seismic_event.dart';
import '../etna_theme.dart';

/// The details of a single earthquake.
///
/// A PURE widget: it doesn't know an AI exists, what JSON is, or what Firebase
/// is. It takes a [SeismicEvent] and draws pixels. That's what lets it open
/// in the Widget Previewer, which runs on Flutter Web without plugins.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final SeismicEvent event;

  /// Optional tap: in the app the adapter wires it up, in the previewer it
  /// stays null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = event.severity.color(theme.brightness);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Container(
          // Colored stripe as a border rather than a stretched child: inside
          // a ListView the height is unbounded, and a stretch would ask for
          // infinite constraints.
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MagnitudeBadge(event: event, accent: accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.place,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.severity.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _Fact(label: 'Data', value: formatEtnaTime(event.time)),
                    _Fact(
                      label: 'Profondità',
                      value: '${event.depthKm.toStringAsFixed(1)} km',
                    ),
                    _Fact(
                      label: 'Epicentro',
                      value:
                          '${event.latitude.toStringAsFixed(3)}, '
                          '${event.longitude.toStringAsFixed(3)}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'INGV · ${event.eventId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MagnitudeBadge extends StatelessWidget {
  const _MagnitudeBadge({required this.event, required this.accent});

  final SeismicEvent event;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      // FittedBox because font metrics differ between previewer, tests and
      // real device: without it, the badge overflows in at least one of them.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              event.magnitude.toStringAsFixed(1),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              event.magnitudeType,
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- Preview -----------------------------------------------------------
// Fake but realistic data: real places in the Etna area, plausible
// magnitudes. The previewer panel is a moment of the talk, not a test.

final _strongQuake = SeismicEvent(
  eventId: '41287651',
  time: DateTime.utc(2026, 9, 18, 3, 14),
  magnitude: 4.3,
  magnitudeType: 'Mw',
  place: 'Zafferana Etnea (CT)',
  latitude: 37.6921,
  longitude: 15.1053,
  depthKm: 2.4,
);

final _microQuake = SeismicEvent(
  eventId: '41287902',
  time: DateTime.utc(2026, 9, 21, 22, 47),
  magnitude: 1.2,
  magnitudeType: 'ML',
  place: '1 km N Ragalna (CT)',
  latitude: 37.7204,
  longitude: 14.9281,
  depthKm: 11.8,
);

/// Edge case: INGV sometimes doesn't have the location yet.
final _missingPlaceQuake = SeismicEvent(
  eventId: '41288010',
  time: DateTime.utc(2026, 9, 22, 6, 5),
  magnitude: 2.6,
  magnitudeType: 'ML',
  place: 'Località non disponibile',
  latitude: 37.7510,
  longitude: 14.9930,
  depthKm: 0.0,
);

@Preview(
  name: 'EventCard — scossa forte',
  group: 'Catalogo Etna',
  theme: etnaPreviewTheme,
  size: Size(460, 220),
)
Widget eventCardStrong() => EventCard(event: _strongQuake);

@Preview(
  name: 'EventCard — scossa forte (dark)',
  group: 'Catalogo Etna',
  theme: etnaPreviewTheme,
  size: Size(460, 220),
  brightness: Brightness.dark,
)
Widget eventCardStrongDark() => EventCard(event: _strongQuake);

@Preview(
  name: 'EventCard — microsismicità',
  group: 'Catalogo Etna',
  theme: etnaPreviewTheme,
  size: Size(460, 220),
)
Widget eventCardMicro() => EventCard(event: _microQuake);

@Preview(
  name: 'EventCard — dato mancante',
  group: 'Catalogo Etna',
  theme: etnaPreviewTheme,
  size: Size(460, 220),
)
Widget eventCardMissingPlace() => EventCard(event: _missingPlaceQuake);
