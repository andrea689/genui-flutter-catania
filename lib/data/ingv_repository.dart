import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/seismic_event.dart';

/// Bounding box around Etna.
class EtnaBounds {
  const EtnaBounds._();

  static const double minLatitude = 37.4;
  static const double maxLatitude = 37.9;
  static const double minLongitude = 14.7;
  static const double maxLongitude = 15.3;

  /// Approximate center of the crater, used to center the map.
  static const double centerLatitude = 37.751;
  static const double centerLongitude = 14.993;
}

/// Network or protocol error while talking to INGV.
class IngvException implements Exception {
  const IngvException(this.message);

  final String message;

  @override
  String toString() => 'IngvException: $message';
}

/// Access to INGV seismic data through the FDSN web service.
///
/// Open API, no key, with CORS `*`: it works from the browser too.
class IngvRepository {
  IngvRepository({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// How long to wait for INGV before giving up.
  ///
  /// Without it, if the venue Wi-Fi hangs, the model round never ends: neither
  /// with Gemini nor with the local provider. On timeout an [IngvException] is
  /// thrown like for any other network error, the tool sends it back to the
  /// model and the conversation goes on.
  final Duration timeout;

  static const String _host = 'webservices.ingv.it';
  static const String _path = '/fdsnws/event/1/query';

  /// Searches for seismic events in the Etna area.
  ///
  /// [limit] is deliberately low by default: the results end up in the
  /// model's context, and every event costs tokens.
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
      response = await _client.get(uri).timeout(timeout);
    } on Object catch (error) {
      throw IngvException('richiesta fallita: $error');
    }

    // FDSN responds 204 when there are no events: it's not an error.
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

  /// FDSN expects ISO 8601 without a timezone, in UTC.
  static String _formatTime(DateTime time) =>
      time.toUtc().toIso8601String().split('.').first;

  void dispose() => _client.close();
}
