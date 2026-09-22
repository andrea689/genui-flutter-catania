import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/ingv_repository.dart';
import '../../domain/seismic_event.dart';
import '../etna_theme.dart';

/// Gli epicentri su una mappa OSM.
///
/// Widget PURO. L'unica concessione alla testabilita' e' [tileProvider]:
/// i golden test iniettano un provider offline, altrimenti il test
/// proverebbe a scaricare tile da internet e fallirebbe.
class MapCard extends StatelessWidget {
  const MapCard({
    super.key,
    required this.events,
    this.title,
    this.tileProvider,
    this.onEventTap,
  });

  final List<SeismicEvent> events;
  final String? title;

  /// Sorgente delle tile. Null = OSM di rete.
  final TileProvider? tileProvider;

  final void Function(SeismicEvent event)? onEventTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SizedBox(
            height: 260,
            child: events.isEmpty
                ? _EmptyState(theme: theme)
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 10.2,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      _MaybeDarkened(
                        dark: theme.brightness == Brightness.dark,
                        child: TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'org.flutter.catania.etna',
                          tileProvider: tileProvider,
                        ),
                      ),
                      MarkerLayer(
                        markers: [
                          for (final event in events)
                            Marker(
                              point: LatLng(event.latitude, event.longitude),
                              width: 34,
                              height: 34,
                              child: _Epicenter(
                                event: event,
                                onTap: onEventTap == null
                                    ? null
                                    : () => onEventTap!(event),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Text(
                  '${events.length} '
                  '${events.length == 1 ? 'epicentro' : 'epicentri'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  'INGV · OpenStreetMap',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Centra sugli eventi se ci sono, altrimenti sul cratere.
  LatLng get _center {
    if (events.isEmpty) {
      return const LatLng(
        EtnaBounds.centerLatitude,
        EtnaBounds.centerLongitude,
      );
    }
    final latitude =
        events.map((e) => e.latitude).reduce((a, b) => a + b) / events.length;
    final longitude =
        events.map((e) => e.longitude).reduce((a, b) => a + b) / events.length;
    return LatLng(latitude, longitude);
  }
}

class _Epicenter extends StatelessWidget {
  const _Epicenter({required this.event, this.onTap});

  final SeismicEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = event.severity.color(Theme.of(context).brightness);
    // Il raggio racconta la magnitudo senza bisogno di una legenda.
    final diameter = 12.0 + event.magnitude * 4.0;

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${event.place} · ${event.magnitudeLabel}',
        child: Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        'Nessun epicentro nel periodo',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// --- Preview -----------------------------------------------------------

final _swarm = <SeismicEvent>[
  SeismicEvent(
    eventId: '41287651',
    time: DateTime.utc(2026, 9, 18, 3, 14),
    magnitude: 4.3,
    magnitudeType: 'Mw',
    place: 'Zafferana Etnea (CT)',
    latitude: 37.6921,
    longitude: 15.1053,
    depthKm: 2.4,
  ),
  SeismicEvent(
    eventId: '41287702',
    time: DateTime.utc(2026, 9, 18, 3, 31),
    magnitude: 3.1,
    magnitudeType: 'ML',
    place: 'Milo (CT)',
    latitude: 37.7268,
    longitude: 15.1189,
    depthKm: 1.9,
  ),
  SeismicEvent(
    eventId: '41287733',
    time: DateTime.utc(2026, 9, 18, 4, 2),
    magnitude: 2.4,
    magnitudeType: 'ML',
    place: '2 km SE Nicolosi (CT)',
    latitude: 37.6012,
    longitude: 15.0331,
    depthKm: 5.6,
  ),
  SeismicEvent(
    eventId: '41287811',
    time: DateTime.utc(2026, 9, 19, 1, 12),
    magnitude: 1.8,
    magnitudeType: 'ML',
    place: '1 km N Ragalna (CT)',
    latitude: 37.7204,
    longitude: 14.9281,
    depthKm: 11.8,
  ),
  SeismicEvent(
    eventId: '41287840',
    time: DateTime.utc(2026, 9, 20, 18, 44),
    magnitude: 2.9,
    magnitudeType: 'ML',
    place: 'Bronte (CT)',
    latitude: 37.7899,
    longitude: 14.8321,
    depthKm: 8.2,
  ),
];

@Preview(
  name: 'MapCard — sciame sismico',
  group: 'Catalogo Etna',
  size: Size(460, 400),
)
Widget mapCardSwarm() =>
    MapCard(title: 'Sciame del 18 settembre', events: _swarm);

@Preview(
  name: 'MapCard — sciame sismico (dark)',
  group: 'Catalogo Etna',
  size: Size(460, 400),
  brightness: Brightness.dark,
)
Widget mapCardSwarmDark() =>
    MapCard(title: 'Sciame del 18 settembre', events: _swarm);

@Preview(
  name: 'MapCard — nessun evento',
  group: 'Catalogo Etna',
  size: Size(460, 400),
)
Widget mapCardEmpty() =>
    const MapCard(title: 'Ultime 24 ore', events: <SeismicEvent>[]);

/// Scurisce i tile della mappa quando il tema e' scuro.
///
/// I tile restano quelli di OpenStreetMap: liberi, senza chiave, senza
/// attribuzioni aggiuntive. Le alternative gia' scure (CARTO, Stadia) oggi
/// vogliono una API key, e sul loro tile compare "API KEY REQUIRED".
///
/// E' la stessa ricetta delle dark map sul web — `invert(1) hue-rotate(180deg)`
/// — applicata **solo ai tile**: i marker restano fuori dal filtro, altrimenti
/// gli accenti di magnitudo verrebbero invertiti anche loro.
class _MaybeDarkened extends StatelessWidget {
  const _MaybeDarkened({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  /// Inverte i canali. Da sola farebbe diventare i verdi magenta.
  static const _invert = <double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ];

  /// Ruota la tinta di 180 gradi e rimette i colori vicini al naturale:
  /// il verde torna verde, il mare torna blu, ma su fondo scuro.
  static const _hueRotate180 = <double>[
    -0.574, 1.430, 0.144, 0, 0, //
    0.426, 0.430, 0.144, 0, 0, //
    0.426, 1.430, -0.856, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Smorza la saturazione al 55%. Senza, il verde del parco tira l'occhio
  /// piu' degli epicentri, che sono l'unica cosa che conta sulla mappa.
  static const _desaturate = <double>[
    0.646, 0.322, 0.032, 0, 0, //
    0.096, 0.872, 0.032, 0, 0, //
    0.096, 0.322, 0.582, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    if (!dark) return child;

    // L'esterno si applica dopo l'interno: inverte, ruota, smorza.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_desaturate),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_hueRotate180),
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_invert),
          child: child,
        ),
      ),
    );
  }
}
