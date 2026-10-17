import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A GeoJSON response as INGV actually sends it.
const String _geoJson = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "eventId": 41287651,
        "time": "2026-09-18T03:14:22.180000",
        "magType": "Mw",
        "mag": 4.3,
        "place": "Zafferana Etnea (CT)"
      },
      "geometry": { "type": "Point", "coordinates": [15.1053, 37.6921, 2.4] }
    },
    {
      "type": "Feature",
      "properties": {
        "eventId": 41287702,
        "time": "2026-09-19T12:31:05.000000",
        "magType": "ML",
        "mag": 1.8,
        "place": "1 km N Ragalna (CT)"
      },
      "geometry": { "type": "Point", "coordinates": [14.9281, 37.7204, 11.8] }
    }
  ]
}
''';

void main() {
  test('interpreta il GeoJSON FDSN e ordina dal più recente', () async {
    late Uri captured;
    final repository = IngvRepository(
      client: MockClient((request) async {
        captured = request.url;
        return http.Response(_geoJson, 200);
      }),
    );

    final events = await repository.search(
      startTime: DateTime.utc(2026, 9, 15),
      endTime: DateTime.utc(2026, 9, 22),
      minMagnitude: 1.5,
      limit: 20,
    );

    // coordinates is [lon, lat, depth]: the order is the classic trap.
    expect(events, hasLength(2));
    expect(events.first.eventId, '41287702');
    expect(events.last.latitude, 37.6921);
    expect(events.last.longitude, 15.1053);
    expect(events.last.depthKm, 2.4);
    expect(events.last.magnitudeType, 'Mw');
    expect(events.last.severity.name, 'strong');

    // The query must stay inside the Etna bounding box.
    expect(captured.queryParameters['minlat'], '37.4');
    expect(captured.queryParameters['maxlat'], '37.9');
    expect(captured.queryParameters['minlon'], '14.7');
    expect(captured.queryParameters['maxlon'], '15.3');
    expect(captured.queryParameters['format'], 'geojson');
    expect(captured.queryParameters['minmagnitude'], '1.5');
    expect(captured.queryParameters['limit'], '20');
    expect(captured.queryParameters['starttime'], '2026-09-15T00:00:00');
  });

  test('204 significa "nessun evento", non errore', () async {
    final repository = IngvRepository(
      client: MockClient((_) async => http.Response('', 204)),
    );
    expect(await repository.search(startTime: DateTime.utc(2026)), isEmpty);
  });

  test('un 500 diventa IngvException', () async {
    final repository = IngvRepository(
      client: MockClient((_) async => http.Response('boom', 500)),
    );
    expect(
      () => repository.search(startTime: DateTime.utc(2026)),
      throwsA(isA<IngvException>()),
    );
  });

  test('una FeatureCollection vuota torna una lista vuota', () async {
    final repository = IngvRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': <Object>[]}),
          200,
        ),
      ),
    );
    expect(await repository.search(startTime: DateTime.utc(2026)), isEmpty);
  });

  test(
    'un INGV che non risponde diventa IngvException entro il timeout',
    () async {
      final repository = IngvRepository(
        // A request that never finishes: the venue Wi-Fi hanging.
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        repository.search(startTime: DateTime.utc(2026)),
        throwsA(
          isA<IngvException>().having(
            (error) => error.message,
            'message',
            contains('TimeoutException'),
          ),
        ),
      );
    },
  );

  test('il timeout di default è 10 secondi', () {
    final repository = IngvRepository();
    addTearDown(repository.dispose);

    expect(repository.timeout, const Duration(seconds: 10));
  });
}
