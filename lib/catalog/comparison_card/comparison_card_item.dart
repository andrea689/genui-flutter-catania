import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'comparison_card.dart';

final Schema _periodSchema = S.object(
  description: 'Il riassunto aggregato di un periodo.',
  properties: {
    'label': S.string(description: 'Nome del periodo, es. "Agosto 2026".'),
    'eventCount': S.integer(description: 'Numero di eventi nel periodo.'),
    'maxMagnitude': S.number(description: 'Magnitudo massima registrata.'),
    'averageMagnitude': S.number(description: 'Magnitudo media.'),
  },
  required: ['label', 'eventCount', 'maxMagnitude', 'averageMagnitude'],
);

/// L'adapter fra il protocollo A2UI e [ComparisonCard].
///
/// Nota: qui l'AI passa numeri gia' aggregati, non la lista di eventi.
/// L'aggregazione la fa il modello a partire dai dati del tool: e' una
/// decisione di presentazione, e in GenUI le decisioni di presentazione sono
/// le sue.
final CatalogItem comparisonCardItem = CatalogItem(
  name: 'ComparisonCard',
  dataSchema: S.object(
    description:
        'Il confronto fra due periodi. Usala quando l utente chiede di '
        'paragonare, per esempio "confronta con agosto".',
    properties: {
      'title': S.string(description: 'Titolo della card.'),
      'previous': _periodSchema,
      'current': _periodSchema,
    },
    required: ['previous', 'current'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as Map<String, Object?>;
    return ComparisonCard(
      title: data['title'] as String?,
      previous: _parsePeriod(data['previous']! as Map<String, Object?>),
      current: _parsePeriod(data['current']! as Map<String, Object?>),
    );
  },
);

PeriodSummary _parsePeriod(Map<String, Object?> json) => PeriodSummary(
  label: '${json['label'] ?? 'Periodo'}',
  eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
  maxMagnitude: (json['maxMagnitude'] as num?)?.toDouble() ?? 0,
  averageMagnitude: (json['averageMagnitude'] as num?)?.toDouble() ?? 0,
);
