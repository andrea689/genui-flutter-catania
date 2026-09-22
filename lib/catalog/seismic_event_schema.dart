import 'package:json_schema_builder/json_schema_builder.dart';

import '../domain/seismic_event.dart';

/// Lo schema di una scossa, come la vede l'AI.
///
/// Definito una volta sola e riusato da tutte le card che parlano di eventi:
/// se il vocabolario cambia, cambia in un posto.
///
/// Le `description` non sono commenti: sono l'unica documentazione che il
/// modello legge. Vanno scritte per lui.
final Schema seismicEventSchema = S.object(
  description: 'Un evento sismico registrato dall INGV.',
  properties: {
    'eventId': S.string(description: 'Identificativo INGV dell evento.'),
    'time': S.string(
      description:
          'Istante dell evento in formato ISO 8601 UTC, '
          'es. 2026-09-18T03:14:00Z.',
    ),
    'magnitude': S.number(description: 'Magnitudo, es. 3.4.'),
    'magnitudeType': S.string(
      description: 'Scala della magnitudo, es. ML oppure Mw.',
    ),
    'place': S.string(
      description: 'Localita di riferimento, es. "1 km N Ragalna (CT)".',
    ),
    'latitude': S.number(description: 'Latitudine dell epicentro.'),
    'longitude': S.number(description: 'Longitudine dell epicentro.'),
    'depthKm': S.number(description: 'Profondita ipocentrale in km.'),
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

/// Converte il JSON dell'AI in un oggetto di dominio.
///
/// Tollerante per scelta: un modello alpha sbaglia i tipi, e una card che
/// degrada e' meglio di una schermata di errore davanti a una platea.
SeismicEvent parseSeismicEvent(Map<String, Object?> json) {
  return SeismicEvent(
    eventId: '${json['eventId'] ?? '—'}',
    time:
        DateTime.tryParse('${json['time']}')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    magnitude: _toDouble(json['magnitude']),
    magnitudeType: '${json['magnitudeType'] ?? 'ML'}',
    place: '${json['place'] ?? 'Localita non disponibile'}',
    latitude: _toDouble(json['latitude']),
    longitude: _toDouble(json['longitude']),
    depthKm: _toDouble(json['depthKm']),
  );
}

/// Legge una lista di eventi da una property, ignorando le voci malformate.
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
