import 'package:firebase_ai/firebase_ai.dart';

import '../data/ingv_repository.dart';
import '../domain/seismic_event.dart';
import 'tool_loop.dart';

/// Il tool che Gemini puo' chiamare per avere dati sismici veri.
///
/// Dichiarazione e implementazione stanno insieme apposta: se cambia lo schema
/// e non cambia l'handler, il compilatore non aiuta, ma la distanza si'.
class EtnaTools {
  EtnaTools(this._repository);

  final IngvRepository _repository;

  static const String searchEarthquakesName = 'searchEarthquakes';

  /// La dichiarazione passata al modello.
  static final FunctionDeclaration searchEarthquakes = FunctionDeclaration(
    searchEarthquakesName,
    'Cerca i terremoti registrati dall INGV nell area dell Etna. '
    'Usa questa funzione ogni volta che servono dati sismici reali: '
    'non inventare mai magnitudo, date o localita.',
    parameters: {
      'daysBack': Schema.integer(
        description:
            'Quanti giorni indietro cercare a partire da oggi. '
            'Es. 7 per "questa settimana", 30 per "questo mese".',
      ),
      'minMagnitude': Schema.number(
        description:
            'Magnitudo minima. Default 1.0. Usa 2.5 per "scosse '
            'significative".',
      ),
      'limit': Schema.integer(
        description: 'Numero massimo di eventi da restituire. Default 50.',
      ),
      'offsetDays': Schema.integer(
        description:
            'Sposta la finestra indietro nel tempo di N giorni, per '
            'confrontare periodi diversi. Es. per "agosto" rispetto a oggi.',
      ),
    },
    optionalParameters: ['minMagnitude', 'limit', 'offsetDays'],
  );

  /// I tool esposti al modello.
  static List<Tool> get all => [
    Tool.functionDeclarations([searchEarthquakes]),
  ];

  /// Gli handler, indicizzati per nome, come li vuole [ToolLoop].
  Map<String, ToolHandler> get handlers => {
    searchEarthquakesName: _handleSearchEarthquakes,
  };

  Future<Map<String, Object?>> _handleSearchEarthquakes(
    Map<String, Object?> args,
  ) async {
    final daysBack = (args['daysBack'] as num?)?.toInt() ?? 7;
    final offsetDays = (args['offsetDays'] as num?)?.toInt() ?? 0;
    final minMagnitude = (args['minMagnitude'] as num?)?.toDouble() ?? 1.0;
    final limit = (args['limit'] as num?)?.toInt() ?? 50;

    final now = DateTime.now().toUtc();
    final endTime = now.subtract(Duration(days: offsetDays));
    final startTime = endTime.subtract(Duration(days: daysBack));

    final events = await _repository.search(
      startTime: startTime,
      endTime: endTime,
      minMagnitude: minMagnitude,
      limit: limit,
    );

    return {
      'periodStart': startTime.toIso8601String(),
      'periodEnd': endTime.toIso8601String(),
      'count': events.length,
      'events': events.map(_toToolJson).toList(),
    };
  }

  /// Forma compatta: ogni campo in piu' e' contesto che il modello paga.
  static Map<String, Object?> _toToolJson(SeismicEvent event) => {
    'eventId': event.eventId,
    'time': event.time.toIso8601String(),
    'magnitude': event.magnitude,
    'magnitudeType': event.magnitudeType,
    'place': event.place,
    'latitude': event.latitude,
    'longitude': event.longitude,
    'depthKm': event.depthKm,
  };
}
