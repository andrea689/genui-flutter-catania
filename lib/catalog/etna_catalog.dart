import 'package:genui/genui.dart';

import 'comparison_card/comparison_card_item.dart';
import 'event_card/event_card_item.dart';
import 'map_card/map_card_item.dart';
import 'timeline_chart/timeline_chart_item.dart';

/// Il vocabolario concesso all'AI.
///
/// Questa lista e' contemporaneamente il dizionario e la sandbox: il modello
/// non puo' renderizzare nulla che non sia qui dentro. Aggiungere una voce e'
/// un atto deliberato; non esiste modo per l'AI di inventarsene una.
abstract final class EtnaCatalog {
  EtnaCatalog._();

  static const String catalogId = 'flutter-catania.dev:etna';

  /// Le quattro card del dominio, sopra i widget di base del package.
  static final List<CatalogItem> items = [
    eventCardItem,
    mapCardItem,
    timelineChartItem,
    comparisonCardItem,
  ];

  /// Il catalogo completo: i widget di base piu' quelli dell'Etna.
  ///
  /// `asNoAssetCatalog` toglie audio, immagini e video: l'app non ne usa, e
  /// ogni voce in piu' e' contesto che il modello paga ad ogni turno.
  static Catalog asCatalog() => BasicCatalogItems.asNoAssetCatalog().copyWith(
    newItems: items,
    catalogId: catalogId,
    systemPromptFragments: [_rules],
  );

  static const String _rules = '''
Sei l'assistente sismico dell'Etna. Rispondi in italiano.

SCELTA DELLA CARD — e' la decisione piu' importante che prendi:
- EventCard: una singola scossa in dettaglio ("la scossa piu' forte").
- MapCard: DOVE sono avvenute le scosse, o il quadro di uno sciame.
- TimelineChart: QUANDO sono avvenute, l'andamento nel tempo.
- ComparisonCard: il paragone fra due periodi ("confronta con agosto").

Puoi comporne piu' di una nella stessa risposta, dentro una Column: per
"cosa e' successo questa settimana?" una MapCard e una TimelineChart insieme
raccontano piu' di ognuna da sola.

DATI:
- Chiama sempre searchEarthquakes prima di parlare di scosse.
- Non inventare MAI magnitudo, date, localita' o identificativi: usa solo
  i valori tornati dal tool, copiati alla lettera.
- Per ComparisonCard i numeri aggregati li calcoli tu dai dati del tool.
- Se il tool non torna eventi, dillo con un Text: non inventare una card vuota.

Accompagna sempre la UI con una riga di testo che risponda alla domanda.
''';
}
