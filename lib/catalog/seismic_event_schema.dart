import 'package:json_schema_builder/json_schema_builder.dart';

import '../domain/seismic_event.dart';

/// The schema of an earthquake, as the AI sees it.
///
/// Defined once and reused by every card that deals with events: if the
/// vocabulary changes, it changes in one place.
///
/// The `description`s aren't comments: they're the only documentation the
/// model reads. Write them for the model.
final Schema seismicEventSchema = S.object(
  description: 'Un evento sismico registrato dall\'INGV.',
  properties: {
    'eventId': S.string(description: 'Identificativo INGV dell\'evento.'),
    'time': S.string(
      description:
          'Istante dell\'evento in formato ISO 8601 UTC, '
          'es. 2026-09-18T03:14:00Z.',
    ),
    'magnitude': S.number(description: 'Magnitudo, es. 3.4.'),
    'magnitudeType': S.string(
      description: 'Scala della magnitudo, es. ML oppure Mw.',
    ),
    'place': S.string(
      description: 'Località di riferimento, es. "1 km N Ragalna (CT)".',
    ),
    'latitude': S.number(description: 'Latitudine dell\'epicentro.'),
    'longitude': S.number(description: 'Longitudine dell\'epicentro.'),
    'depthKm': S.number(description: 'Profondità ipocentrale in km.'),
  },
  required: [
    'eventId',
    'time',
    'magnitude',
    'magnitudeType',
    'place',
    'latitude',
    'longitude',
    'depthKm',
  ],
);

/// Converts the AI's JSON into a domain object.
///
/// Lenient by design: an alpha model gets types wrong, and a card that
/// degrades beats an error screen in front of an audience.
SeismicEvent parseSeismicEvent(Map<String, Object?> json) {
  return SeismicEvent(
    eventId: '${json['eventId'] ?? '—'}',
    time:
        DateTime.tryParse('${json['time']}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    magnitude: _toDouble(json['magnitude']),
    magnitudeType: '${json['magnitudeType'] ?? 'ML'}',
    place: '${json['place'] ?? 'Località non disponibile'}',
    latitude: _toDouble(json['latitude']),
    longitude: _toDouble(json['longitude']),
    depthKm: _toDouble(json['depthKm']),
  );
}

/// Reads a list of events from a property, skipping malformed entries.
List<SeismicEvent> parseSeismicEvents(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, Object?>>()
      .map(parseSeismicEvent)
      .toList(growable: false);
}

double _toDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};
