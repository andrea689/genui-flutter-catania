import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/seismic_event.dart';

/// Bounding box attorno all'Etna, come da spec del talk.
class EtnaBounds {
  const EtnaBounds._();

  static const double minLatitude = 37.4;
  static const double maxLatitude = 37.9;
  static const double minLongitude = 14.7;
  static const double maxLongitude = 15.3;

  /// Centro approssimativo del cratere, per centrare la mappa.
  static const double centerLatitude = 37.751;
  static const double centerLongitude = 14.993;
}

/// Errore di rete o di protocollo parlando con l'INGV.
class IngvException implements Exception {
  const IngvException(this.message);

  final String message;

  @override
  String toString() => 'IngvException: $message';
}

/// Accesso ai dati sismici dell'INGV via web service FDSN.
///
/// API aperta, senza chiave, con CORS `*`: funziona anche dal browser.
class IngvRepository {
  IngvRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'webservices.ingv.it';
  static const String _path = '/fdsnws/event/1/query';

  /// Cerca gli eventi sismici nell'area dell'Etna.
  ///
  /// [limit] e' volutamente basso di default: i risultati finiscono nel
  /// contesto del modello, e ogni evento costa token.
  Future<List<SeismicEvent>> search({
    required DateTime startTime,
    DateTime? endTime,
    double minMagnitude = 1.0,
    int limit = 50,
  }) async {
    final uri = Uri.https(_host, _path, {
      'starttime': _formatTime(startTime),
      if (endTime != null) 'endtime': _formatTime(endTime),
      'minmagnitude': minMagnitude.toString(),
      'minlat': EtnaBounds.minLatitude.toString(),
      'maxlat': EtnaBounds.maxLatitude.toString(),
      'minlon': EtnaBounds.minLongitude.toString(),
      'maxlon': EtnaBounds.maxLongitude.toString(),
      'format': 'geojson',
      'limit': limit.toString(),
    });

    final http.Response response;
    try {
      response = await _client.get(uri);
    } on Object catch (error) {
      throw IngvException('richiesta fallita: $error');
    }

    // L'FDSN risponde 204 quando non ci sono eventi: non e' un errore.
    if (response.statusCode == 204) return const [];
    if (response.statusCode != 200) {
      throw IngvException('INGV ha risposto ${response.statusCode} per $uri');
    }

    final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, Object?>) {
      throw const IngvException('risposta GeoJSON non riconosciuta');
    }
    final features = decoded['features'];
    if (features is! List) return const [];

    return features
        .whereType<Map<String, Object?>>()
        .map(SeismicEvent.fromGeoJsonFeature)
        .toList(growable: false)
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  /// L'FDSN vuole ISO 8601 senza timezone, in UTC.
  static String _formatTime(DateTime time) =>
      time.toUtc().toIso8601String().split('.').first;

  void dispose() => _client.close();
}
