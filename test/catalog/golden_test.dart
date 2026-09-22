// Slide 26 — "come testi una UI che non conosci a priori?"
//
// Non puoi fare golden test sulla composizione: quella la decide il modello a
// runtime e cambia ad ogni giro. Puoi pero' testarne i MATTONI, che sono
// deterministici. E' esattamente per questo che i widget sono puri.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/catalog/comparison_card/comparison_card.dart';
import 'package:genui_flutter_catania/catalog/etna_theme.dart';
import 'package:genui_flutter_catania/catalog/event_card/event_card.dart';
import 'package:genui_flutter_catania/catalog/map_card/map_card.dart';
import 'package:genui_flutter_catania/catalog/timeline_chart/timeline_chart.dart';
import 'package:genui_flutter_catania/domain/seismic_event.dart';

/// Tile finte: senza questo il golden proverebbe a scaricare da OSM.
/// E' il motivo per cui [MapCard.tileProvider] e' iniettabile.
class _OfflineTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(_transparentPng);
}

/// PNG 1x1 trasparente.
final Uint8List _transparentPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

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

final _swarm = <SeismicEvent>[
  _strongQuake,
  SeismicEvent(
    eventId: '41287702',
    time: DateTime.utc(2026, 9, 18, 12, 31),
    magnitude: 3.1,
    magnitudeType: 'ML',
    place: 'Milo (CT)',
    latitude: 37.7268,
    longitude: 15.1189,
    depthKm: 1.9,
  ),
  SeismicEvent(
    eventId: '41287733',
    time: DateTime.utc(2026, 9, 19, 4, 2),
    magnitude: 2.4,
    magnitudeType: 'ML',
    place: '2 km SE Nicolosi (CT)',
    latitude: 37.6012,
    longitude: 15.0331,
    depthKm: 5.6,
  ),
  SeismicEvent(
    eventId: '41287811',
    time: DateTime.utc(2026, 9, 20, 1, 12),
    magnitude: 1.8,
    magnitudeType: 'ML',
    place: '1 km N Ragalna (CT)',
    latitude: 37.7204,
    longitude: 14.9281,
    depthKm: 11.8,
  ),
];

/// Monta un widget con dimensioni e tema fissi, cosi' il golden e' stabile.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(460, 260),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      // Il tema **vero** dell'app, non uno costruito qui: altrimenti i golden
      // fotografano qualcosa che nessuno vede mai.
      theme: brightness == Brightness.dark ? EtnaTheme.dark : EtnaTheme.light,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(8), child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('golden — i mattoni del catalogo', () {
    testWidgets('EventCard, scossa forte', (tester) async {
      await _pump(tester, EventCard(event: _strongQuake));
      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_strong.png'),
      );
    });

    testWidgets('EventCard, tema scuro', (tester) async {
      await _pump(
        tester,
        EventCard(event: _strongQuake),
        brightness: Brightness.dark,
      );
      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_strong_dark.png'),
      );
    });

    testWidgets('TimelineChart, sciame', (tester) async {
      await _pump(
        tester,
        TimelineChart(title: 'Ultimi giorni', events: _swarm),
        size: const Size(460, 320),
      );
      await expectLater(
        find.byType(TimelineChart),
        matchesGoldenFile('goldens/timeline_chart_swarm.png'),
      );
    });

    testWidgets('ComparisonCard, attivita in aumento', (tester) async {
      await _pump(
        tester,
        const ComparisonCard(
          title: 'Settembre rispetto ad agosto',
          previous: PeriodSummary(
            label: 'Agosto 2026',
            eventCount: 48,
            maxMagnitude: 3.2,
            averageMagnitude: 1.74,
          ),
          current: PeriodSummary(
            label: 'Settembre 2026',
            eventCount: 71,
            maxMagnitude: 4.3,
            averageMagnitude: 2.08,
          ),
        ),
        size: const Size(460, 340),
      );
      await expectLater(
        find.byType(ComparisonCard),
        matchesGoldenFile('goldens/comparison_card_increase.png'),
      );
    });

    testWidgets('MapCard, epicentri con tile offline', (tester) async {
      await _pump(
        tester,
        MapCard(
          title: 'Sciame del 18 settembre',
          events: _swarm,
          tileProvider: _OfflineTileProvider(),
        ),
        size: const Size(460, 400),
      );
      await expectLater(
        find.byType(MapCard),
        matchesGoldenFile('goldens/map_card_swarm.png'),
      );
    });
  });

  group('comportamento dei widget puri', () {
    testWidgets('EventCard mostra magnitudo, luogo e profondita', (
      tester,
    ) async {
      await _pump(tester, EventCard(event: _strongQuake));
      expect(find.text('4.3'), findsOneWidget);
      expect(find.text('Mw'), findsOneWidget);
      expect(find.text('Zafferana Etnea (CT)'), findsOneWidget);
      expect(find.text('2.4 km'), findsOneWidget);
      expect(find.text('Forte'), findsOneWidget);
    });

    testWidgets('EventCard notifica il tap', (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        EventCard(event: _strongQuake, onTap: () => tapped++),
      );
      await tester.tap(find.byType(EventCard));
      expect(tapped, 1);
    });

    testWidgets('MapCard senza eventi degrada invece di esplodere', (
      tester,
    ) async {
      await _pump(
        tester,
        const MapCard(events: <SeismicEvent>[]),
        size: const Size(460, 400),
      );
      expect(find.text('Nessun epicentro nel periodo'), findsOneWidget);
      expect(find.text('0 epicentri'), findsOneWidget);
    });

    testWidgets('TimelineChart senza eventi non disegna', (tester) async {
      await _pump(
        tester,
        const TimelineChart(events: <SeismicEvent>[]),
        size: const Size(460, 320),
      );
      expect(find.text('Nessun evento nel periodo'), findsOneWidget);
    });

    testWidgets('ComparisonCard calcola la variazione percentuale', (
      tester,
    ) async {
      await _pump(
        tester,
        const ComparisonCard(
          previous: PeriodSummary(
            label: 'Prima',
            eventCount: 50,
            maxMagnitude: 3,
            averageMagnitude: 2,
          ),
          current: PeriodSummary(
            label: 'Dopo',
            eventCount: 75,
            maxMagnitude: 4,
            averageMagnitude: 2.5,
          ),
        ),
        size: const Size(460, 340),
      );
      expect(find.text('25 eventi in piu (50%)'), findsOneWidget);
    });
  });
}
