import 'package:freezed_annotation/freezed_annotation.dart';

part 'seismic_event.freezed.dart';
part 'seismic_event.g.dart';

/// An earthquake, as reported by INGV.
///
/// Pure domain model: no references to AI, AI JSON or Firebase.
/// Used by both the catalog widgets and the repository.
@freezed
abstract class SeismicEvent with _$SeismicEvent {
  const factory SeismicEvent({
    /// INGV event identifier.
    required String eventId,

    /// Time of the event, in UTC.
    required DateTime time,

    required double magnitude,

    /// Magnitude scale, e.g. `ML`, `Mw`.
    required String magnitudeType,

    /// Reference location, e.g. `1 km N Ragalna (CT)`.
    required String place,

    required double latitude,
    required double longitude,

    /// Hypocentral depth in km.
    required double depthKm,
  }) = _SeismicEvent;

  const SeismicEvent._();

  factory SeismicEvent.fromJson(Map<String, Object?> json) =>
      _$SeismicEventFromJson(json);

  /// Builds the event from a GeoJSON feature of the INGV FDSN API.
  ///
  /// `geometry.coordinates` is `[lon, lat, depth]` — in that order.
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

  /// Compact magnitude label, e.g. `ML 3.4`.
  String get magnitudeLabel => '$magnitudeType ${magnitude.toStringAsFixed(1)}';

  /// Classification used to color the cards and the map markers.
  SeismicSeverity get severity => switch (magnitude) {
    >= 4.0 => SeismicSeverity.strong,
    >= 3.0 => SeismicSeverity.moderate,
    >= 2.0 => SeismicSeverity.light,
    _ => SeismicSeverity.micro,
  };
}

/// Magnitude bands, for consistent colors across the whole catalog.
enum SeismicSeverity { micro, light, moderate, strong }
