import 'package:genui/genui.dart';

import 'comparison_card/comparison_card_item.dart';
import 'event_card/event_card_item.dart';
import 'map_card/map_card_item.dart';
import 'timeline_chart/timeline_chart_item.dart';

/// The vocabulary the AI is allowed to use.
///
/// This list is both the dictionary and the sandbox: the model can't render
/// anything that isn't in here. Adding an entry is a deliberate act; there's
/// no way for the AI to make one up.
abstract final class EtnaCatalog {
  EtnaCatalog._();

  static const String catalogId = 'flutter-catania.dev:etna';

  /// The four domain cards, on top of the package's basic widgets.
  static final List<CatalogItem> items = [
    eventCardItem,
    mapCardItem,
    timelineChartItem,
    comparisonCardItem,
  ];

  /// The full catalog: the basic widgets plus the Etna ones.
  ///
  /// `asNoAssetCatalog` drops audio, images and video: the app doesn't use
  /// them, and every extra entry is context the model pays for on every turn.
  static Catalog asCatalog() => BasicCatalogItems.asNoAssetCatalog().copyWith(
    newItems: items,
    catalogId: catalogId,
    systemPromptFragments: [_rules],
  );

  static const String _rules = '''
Sei l'assistente sismico dell'Etna. Rispondi in italiano.

SCELTA DELLA CARD — è la decisione più importante che prendi:
- EventCard: una singola scossa in dettaglio ("la scossa più forte").
- MapCard: DOVE sono avvenute le scosse, o il quadro di uno sciame.
- TimelineChart: QUANDO sono avvenute, l'andamento nel tempo.
- ComparisonCard: il paragone fra due periodi ("confronta con agosto").

Puoi comporne più di una nella stessa risposta, dentro una Column: per
"cosa è successo questa settimana?" una MapCard e una TimelineChart insieme
raccontano più di ognuna da sola.

DATI:
- Chiama sempre searchEarthquakes prima di parlare di scosse.
- Non inventare MAI magnitudo, date, località o identificativi: usa solo
  i valori tornati dal tool, copiati alla lettera.
- Per ComparisonCard i numeri aggregati li calcoli tu dai dati del tool.
- Se il tool non torna eventi, dillo con un Text: non inventare una card vuota.

Accompagna sempre la UI con una riga di testo che risponda alla domanda.
''';
}
