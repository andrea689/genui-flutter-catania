import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../domain/seismic_event.dart';
import '../etna_theme.dart';

/// Il dettaglio di una singola scossa.
///
/// Widget PURO: non sa che esiste un'AI, non sa cos'e' il JSON, non sa cos'e'
/// Firebase. Prende un [SeismicEvent] e disegna pixel. E' questo che permette
/// di aprirlo nel Widget Previewer, che gira su Flutter Web senza plugin.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final SeismicEvent event;

  /// Tap opzionale: in app lo collega l'adapter, nel previewer resta null.
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
          // Fascia colorata come bordo invece che come figlio in stretch:
          // dentro una ListView l'altezza e' illimitata, e uno stretch
          // chiederebbe vincoli infiniti.
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
                      label: 'Profondita',
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
      // FittedBox perche' le metriche dei font cambiano fra previewer, test e
      // dispositivo reale: senza, il badge trabocca in almeno uno dei tre.
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
// Dati finti ma realistici: localita' vere dell'area etnea, magnitudo
// plausibili. Il pannello del previewer e' un momento del talk, non un test.

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

/// Caso limite: l'INGV a volte non ha ancora la localita'.
final _missingPlaceQuake = SeismicEvent(
  eventId: '41288010',
  time: DateTime.utc(2026, 9, 22, 6, 5),
  magnitude: 2.6,
  magnitudeType: 'ML',
  place: 'Localita non disponibile',
  latitude: 37.7510,
  longitude: 14.9930,
  depthKm: 0.0,
);

@Preview(
  name: 'EventCard — scossa forte',
  group: 'Catalogo Etna',
  size: Size(460, 220),
)
Widget eventCardStrong() => EventCard(event: _strongQuake);

@Preview(
  name: 'EventCard — scossa forte (dark)',
  group: 'Catalogo Etna',
  size: Size(460, 220),
  brightness: Brightness.dark,
)
Widget eventCardStrongDark() => EventCard(event: _strongQuake);

@Preview(
  name: 'EventCard — microsismicita',
  group: 'Catalogo Etna',
  size: Size(460, 220),
)
Widget eventCardMicro() => EventCard(event: _microQuake);

@Preview(
  name: 'EventCard — dato mancante',
  group: 'Catalogo Etna',
  size: Size(460, 220),
)
Widget eventCardMissingPlace() => EventCard(event: _missingPlaceQuake);
