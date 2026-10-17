import 'package:firebase_ai/firebase_ai.dart';

import '../data/ingv_repository.dart';
import '../domain/seismic_event.dart';
import 'tool_loop.dart';

/// The tool Gemini can call to get real seismic data.
///
/// Declaration and implementation live together on purpose: if the schema
/// changes and the handler doesn't, the compiler won't catch it, but keeping
/// them side by side helps.
class EtnaTools {
  EtnaTools(this._repository);

  final IngvRepository _repository;

  static const String searchEarthquakesName = 'searchEarthquakes';

  /// The declaration passed to the model.
  static final FunctionDeclaration searchEarthquakes = FunctionDeclaration(
    searchEarthquakesName,
    'Cerca i terremoti registrati dall\'INGV nell\'area dell\'Etna. '
    'Usa questa funzione ogni volta che servono dati sismici reali: '
    'non inventare mai magnitudo, date o località.',
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

  /// The tools exposed to the model.
  static List<Tool> get all => [
    Tool.functionDeclarations([searchEarthquakes]),
  ];

  /// The handlers, keyed by name, as [ToolLoop] expects them.
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

  /// Compact shape: every extra field is context the model pays for.
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
