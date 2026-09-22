// Slide 26, seconda meta': i test di schema sugli adapter.
//
// Il catalogo e' il contratto fra te e il modello. Questi test verificano che
// il contratto sia quello che credi: i nomi che il prompt promette, le
// property richieste, e che dal JSON esca davvero il widget puro giusto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_flutter_catania/catalog/comparison_card/comparison_card.dart';
import 'package:genui_flutter_catania/catalog/comparison_card/comparison_card_item.dart';
import 'package:genui_flutter_catania/catalog/etna_catalog.dart';
import 'package:genui_flutter_catania/catalog/event_card/event_card.dart';
import 'package:genui_flutter_catania/catalog/event_card/event_card_item.dart';
import 'package:genui_flutter_catania/catalog/map_card/map_card.dart';
import 'package:genui_flutter_catania/catalog/map_card/map_card_item.dart';
import 'package:genui_flutter_catania/catalog/seismic_event_schema.dart';
import 'package:genui_flutter_catania/catalog/timeline_chart/timeline_chart.dart';
import 'package:genui_flutter_catania/catalog/timeline_chart/timeline_chart_item.dart';

const Map<String, Object?> _sampleEventJson = {
  'eventId': '41287651',
  'time': '2026-09-18T03:14:00Z',
  'magnitude': 4.3,
  'magnitudeType': 'Mw',
  'place': 'Zafferana Etnea (CT)',
  'latitude': 37.6921,
  'longitude': 15.1053,
  'depthKm': 2.4,
};

/// Monta un CatalogItem come farebbe il runtime, e restituisce il widget.
Future<void> _pumpItem(
  WidgetTester tester,
  CatalogItem item,
  Map<String, Object?> data,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => item.widgetBuilder(
            CatalogItemContext(
              data: data,
              id: 'root',
              type: item.name,
              buildChild: (id, [dataContext]) => const SizedBox.shrink(),
              dispatchEvent: (_) {},
              buildContext: context,
              dataContext: DataContext(InMemoryDataModel(), DataPath.root),
              getComponent: (_) => null,
              getCatalogItem: (_) => null,
              surfaceId: 'surface-1',
              reportError: (error, stack) => fail('reportError: $error'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('il catalogo e il contratto col modello', () {
    test('espone esattamente le quattro card del dominio', () {
      expect(
        EtnaCatalog.items.map((item) => item.name),
        containsAll(<String>[
          'EventCard',
          'MapCard',
          'TimelineChart',
          'ComparisonCard',
        ]),
      );
      expect(EtnaCatalog.items, hasLength(4));
    });

    test('il catalogo completo contiene le card e i widget di base', () {
      final names = EtnaCatalog.asCatalog().items.map((i) => i.name).toSet();
      expect(names, containsAll(<String>['EventCard', 'Column', 'Text']));
      // asNoAssetCatalog: niente asset che l'app non usa e il modello
      // pagherebbe comunque in token.
      expect(names, isNot(contains('Video')));
      expect(names, isNot(contains('AudioPlayer')));
    });

    test('il catalogo ha un id proprio, non quello di default', () {
      expect(EtnaCatalog.asCatalog().catalogId, EtnaCatalog.catalogId);
    });

    test('il system prompt nomina tutte e quattro le card', () {
      final prompt = PromptBuilder.chat(
        catalog: EtnaCatalog.asCatalog(),
      ).systemPromptJoined();
      for (final name in const [
        'EventCard',
        'MapCard',
        'TimelineChart',
        'ComparisonCard',
      ]) {
        expect(prompt, contains(name), reason: '$name assente dal prompt');
      }
    });
  });

  group('schema degli adapter', () {
    test(
      'lo schema di un evento richiede tutti i campi che il parser legge',
      () {
        final required = (seismicEventSchema.value['required']! as List)
            .cast<String>();
        expect(
          required,
          containsAll(<String>[
            'eventId',
            'time',
            'magnitude',
            'magnitudeType',
            'place',
            'latitude',
            'longitude',
            'depthKm',
          ]),
        );
      },
    );

    test('dataSchema inietta il discriminante `component`', () {
      for (final item in EtnaCatalog.items) {
        final schema = item.dataSchema.value;
        final properties = schema['properties']! as Map<String, Object?>;
        final component = properties['component']! as Map<String, Object?>;

        expect(component['enum'], [item.name]);
        expect(
          (schema['required']! as List).cast<String>(),
          contains('component'),
          reason: '${item.name}: `component` deve essere required',
        );
      }
    });

    test('ogni card descrive a parole quando va usata', () {
      for (final item in EtnaCatalog.items) {
        final description = item.dataSchema.value['description'] as String?;
        expect(
          description,
          isNotNull,
          reason: '${item.name} senza description: il modello sceglie a caso',
        );
        expect(description!.length, greaterThan(40));
      }
    });

    test('EventCard richiede `event`, le liste richiedono `events`', () {
      expect(
        (eventCardItem.dataSchema.value['required']! as List),
        contains('event'),
      );
      for (final item in [mapCardItem, timelineChartItem]) {
        expect(
          (item.dataSchema.value['required']! as List),
          contains('events'),
          reason: item.name,
        );
      }
      expect(
        (comparisonCardItem.dataSchema.value['required']! as List),
        containsAll(<String>['previous', 'current']),
      );
    });
  });

  group('adapter: dal JSON del modello al widget puro', () {
    testWidgets('EventCard', (tester) async {
      await _pumpItem(tester, eventCardItem, {
        'component': 'EventCard',
        'event': _sampleEventJson,
      });
      expect(find.byType(EventCard), findsOneWidget);
      expect(find.text('Zafferana Etnea (CT)'), findsOneWidget);
      expect(find.text('4.3'), findsOneWidget);
    });

    testWidgets('MapCard', (tester) async {
      await _pumpItem(tester, mapCardItem, {
        'component': 'MapCard',
        'title': 'Sciame',
        'events': [_sampleEventJson, _sampleEventJson],
      });
      final card = tester.widget<MapCard>(find.byType(MapCard));
      expect(card.title, 'Sciame');
      expect(card.events, hasLength(2));
      expect(card.events.first.place, 'Zafferana Etnea (CT)');
    });

    testWidgets('TimelineChart', (tester) async {
      await _pumpItem(tester, timelineChartItem, {
        'component': 'TimelineChart',
        'events': [_sampleEventJson],
      });
      final chart = tester.widget<TimelineChart>(find.byType(TimelineChart));
      expect(chart.events.single.magnitude, 4.3);
    });

    testWidgets('ComparisonCard', (tester) async {
      await _pumpItem(tester, comparisonCardItem, {
        'component': 'ComparisonCard',
        'title': 'Confronto',
        'previous': {
          'label': 'Agosto',
          'eventCount': 48,
          'maxMagnitude': 3.2,
          'averageMagnitude': 1.74,
        },
        'current': {
          'label': 'Settembre',
          'eventCount': 71,
          'maxMagnitude': 4.3,
          'averageMagnitude': 2.08,
        },
      });
      final card = tester.widget<ComparisonCard>(find.byType(ComparisonCard));
      expect(card.previous.eventCount, 48);
      expect(card.current.maxMagnitude, 4.3);
    });
  });

  group('il parser regge quello che un modello alpha combina davvero', () {
    test('numeri arrivati come stringhe', () {
      final event = parseSeismicEvent({
        ..._sampleEventJson,
        'magnitude': '4.3',
        'depthKm': '2.4',
      });
      expect(event.magnitude, 4.3);
      expect(event.depthKm, 2.4);
    });

    test('campi mancanti degradano invece di lanciare', () {
      final event = parseSeismicEvent(const {'eventId': 'x'});
      expect(event.magnitude, 0);
      expect(event.place, 'Localita non disponibile');
      expect(event.magnitudeType, 'ML');
    });

    test('una lista con voci malformate scarta solo quelle', () {
      final events = parseSeismicEvents([
        _sampleEventJson,
        'non e un oggetto',
        42,
      ]);
      expect(events, hasLength(1));
    });

    test('events assente non e un crash', () {
      expect(parseSeismicEvents(null), isEmpty);
      expect(parseSeismicEvents('boom'), isEmpty);
    });
  });
}
