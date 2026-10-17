import 'package:genui/genui.dart';

import '../catalog/etna_catalog.dart';

/// What the model is allowed to answer with: the three versions of the same
/// app shown on stage.
///
/// Same model, same tool, same data: only the system prompt and the catalog
/// change.
enum ResponseMode {
  /// The chatbot everyone already has: markdown text, no catalog.
  text('Solo testo'),

  /// GenUI with the package's basic catalog only: cards, columns, text,
  /// buttons. It works, but it isn't the app's own UI yet.
  basic('Catalogo base'),

  /// The full demo: the basic catalog plus the four Etna cards.
  etna('Catalogo Etna');

  const ResponseMode(this.label);

  /// The name shown in the AppBar menu.
  final String label;

  /// The catalog the [SurfaceController] renders from.
  ///
  /// In [text] the model never hears about it, but the controller needs one.
  Catalog get catalog => switch (this) {
    ResponseMode.text => BasicCatalogItems.asNoAssetCatalog(),
    ResponseMode.basic => BasicCatalogItems.asNoAssetCatalog(
      systemPromptFragments: [_basicRules],
    ),
    ResponseMode.etna => EtnaCatalog.asCatalog(),
  };

  /// The system prompt the model receives.
  ///
  /// [basic] and [etna] go through `PromptBuilder`, which adds the A2UI
  /// instructions and the catalog schemas. [text] doesn't: without them the
  /// model doesn't know A2UI exists and answers in plain text.
  String get systemPrompt => switch (this) {
    ResponseMode.text => _textRules,
    ResponseMode.basic || ResponseMode.etna => PromptBuilder.chat(
      catalog: catalog,
    ).systemPromptJoined(),
  };

  static const String _textRules = '''
Sei l'assistente sismico dell'Etna. Rispondi in italiano.

Rispondi solo con testo. Puoi usare il markdown (grassetto, elenchi), ma
niente blocchi JSON e niente codice.

DATI:
- Chiama sempre searchEarthquakes prima di parlare di scosse.
- Non inventare MAI magnitudo, date, località o identificativi: usa solo
  i valori tornati dal tool, copiati alla lettera.
- Se il tool non torna eventi, dillo.
''';

  static const String _basicRules = '''
Sei l'assistente sismico dell'Etna. Rispondi in italiano.

Componi la UI con i componenti del catalogo.

DATI:
- Chiama sempre searchEarthquakes prima di parlare di scosse.
- Non inventare MAI magnitudo, date, località o identificativi: usa solo
  i valori tornati dal tool, copiati alla lettera.
- Se il tool non torna eventi, dillo con un Text: non inventare una card vuota.

Accompagna sempre la UI con una riga di testo che risponda alla domanda.
''';
}
