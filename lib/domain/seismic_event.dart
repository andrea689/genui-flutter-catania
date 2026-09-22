import 'package:freezed_annotation/freezed_annotation.dart';

part 'seismic_event.freezed.dart';
part 'seismic_event.g.dart';

/// Una scossa, come la racconta l'INGV.
///
/// Modello di dominio puro: nessun riferimento ad AI, JSON dell'AI o Firebase.
/// Lo usano sia i widget del catalogo sia il repository.
@freezed
abstract class SeismicEvent with _$SeismicEvent {
  const factory SeismicEvent({
    /// Identificativo INGV dell'evento.
    required String eventId,

    /// Istante dell'evento, in UTC.
    required DateTime time,

    /// Magnitudo.
    required double magnitude,

    /// Scala della magnitudo, es. `ML`, `Mw`.
    required String magnitudeType,

    /// Località di riferimento, es. `1 km N Ragalna (CT)`.
    required String place,

    required double latitude,
    required double longitude,

    /// Profondità ipocentrale in km.
    required double depthKm,
  }) = _SeismicEvent;

  const SeismicEvent._();

  factory SeismicEvent.fromJson(Map<String, Object?> json) =>
      _$SeismicEventFromJson(json);

  /// Costruisce l'evento da una feature GeoJSON dell'API FDSN dell'INGV.
  ///
  /// `geometry.coordinates` e' `[lon, lat, depth]` — in quest'ordine.
  factory SeismicEvent.fromGeoJsonFeature(Map<String, Object?> feature) {
    final properties = feature['properties']! as Map<String, Object?>;
    final geometry = feature['geometry']! as Map<String, Object?>;
    final coordinates = (geometry['coordinates']! as List<Object?>)
        .map((value) => (value as num?)?.toDouble() ?? 0)
        .toList();

    return SeismicEvent(
      eventId: '${properties['eventId']}',
      time: DateTime.parse(properties['time']! as String).toUtc(),
      magnitude: (properties['mag'] as num?)?.toDouble() ?? 0,
      magnitudeType: properties['magType'] as String? ?? 'ML',
      place: properties['place'] as String? ?? 'Località non disponibile',
      longitude: coordinates[0],
      latitude: coordinates[1],
      depthKm: coordinates.length > 2 ? coordinates[2] : 0,
    );
  }

  /// Etichetta compatta della magnitudo, es. `ML 3.4`.
  String get magnitudeLabel => '$magnitudeType ${magnitude.toStringAsFixed(1)}';

  /// Classificazione usata per il colore delle card e dei punti in mappa.
  SeismicSeverity get severity => switch (magnitude) {
    >= 4.0 => SeismicSeverity.strong,
    >= 3.0 => SeismicSeverity.moderate,
    >= 2.0 => SeismicSeverity.light,
    _ => SeismicSeverity.micro,
  };
}

/// Fasce di magnitudo, per dare un colore coerente in tutto il catalogo.
enum SeismicSeverity { micro, light, moderate, strong }
