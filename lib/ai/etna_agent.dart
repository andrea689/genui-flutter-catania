import 'package:firebase_ai/firebase_ai.dart';
import 'package:genui/genui.dart';

import '../catalog/etna_catalog.dart';
import '../data/ingv_repository.dart';
import 'etna_tools.dart';
import 'firebase_llm_gateway.dart';
import 'llm_gateway.dart';
import 'tool_loop.dart';

/// Il modello Gemini usato dalla demo.
///
/// NON usare `gemini-2.5-flash`: si spegne il **16 ottobre 2026**, cioe' il
/// giorno prima del talk. Fine di ogni modello 2.5 nell'ottobre 2026.
///
/// `gemini-3.8-flash` e' stabile (GA dal 2 settembre 2026) ed e' il default
/// raccomandato da Firebase AI Logic. Per la UI generativa conta soprattutto
/// che segua bene le istruzioni: e' quello che tiene i widget dentro lo schema.
///
/// L'alternativa conservativa e' `gemini-3.5-flash`, stabile da maggio 2026 e
/// garantito fino ad almeno maggio 2027. Si cambia senza ricompilare il
/// ragionamento: `--dart-define=GEMINI_MODEL=gemini-3.5-flash`.
const String kGeminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-3.5-flash',
);

/// Mette insieme i pezzi: catalogo, system prompt, tool e transport.
///
/// E' il punto in cui il rischio R1 diventa codice di produzione: [_onSend] e'
/// il corpo di `A2uiTransportAdapter.onSend` e contiene il giro completo.
class EtnaAgent {
  EtnaAgent._({
    required this.catalog,
    required this.controller,
    required this.transport,
    required this.conversation,
    required this.loop,
    required this.repository,
  });

  /// Costruisce il gateway verso Gemini.
  ///
  /// Separato dalla factory perche' lo strumento di verifica in `tool/` lo
  /// avvolge per stampare cosa passa nei due canali.
  static LlmGateway buildFirebaseGateway({Catalog? catalog, FirebaseAI? ai}) {
    final effectiveCatalog = catalog ?? EtnaCatalog.asCatalog();
    final promptBuilder = PromptBuilder.chat(catalog: effectiveCatalog);

    final model = (ai ?? FirebaseAI.googleAI()).generativeModel(
      model: kGeminiModel,
      systemInstruction: Content.system(promptBuilder.systemPromptJoined()),
      tools: EtnaTools.all,
    );

    return FirebaseLlmGateway(model: model, tools: EtnaTools.all);
  }

  /// Costruisce l'agente sopra Firebase AI Logic.
  factory EtnaAgent.firebase({IngvRepository? repository, FirebaseAI? ai}) {
    final catalog = EtnaCatalog.asCatalog();
    return EtnaAgent.custom(
      catalog: catalog,
      gateway: buildFirebaseGateway(catalog: catalog, ai: ai),
      repository: repository ?? IngvRepository(),
    );
  }

  /// Costruisce l'agente sopra un [LlmGateway] qualsiasi.
  ///
  /// Esiste per i test: lo stesso wiring, con un modello finto.
  factory EtnaAgent.custom({
    required Catalog catalog,
    required LlmGateway gateway,
    required IngvRepository repository,
  }) {
    final controller = SurfaceController(catalogs: [catalog]);
    final loop = ToolLoop(
      gateway: gateway,
      tools: EtnaTools(repository).handlers,
    );

    late final A2uiTransportAdapter transport;
    late final EtnaAgent agent;

    transport = A2uiTransportAdapter(
      onSend: (message) => agent._onSend(message),
    );

    return agent = EtnaAgent._(
      catalog: catalog,
      controller: controller,
      transport: transport,
      conversation: Conversation(controller: controller, transport: transport),
      loop: loop,
      repository: repository,
    );
  }

  final Catalog catalog;
  final SurfaceController controller;
  final A2uiTransportAdapter transport;
  final Conversation conversation;

  /// Il loop che gestisce function calling e streaming A2UI.
  final ToolLoop loop;

  /// La sorgente dei dati sismici.
  final IngvRepository repository;

  /// Lo storico, tenuto qui: e' la memoria multi-turno della conversazione.
  final List<LlmMessage> _history = [];

  /// Il corpo di `onSend`. Il giro completo del talk in una funzione.
  Future<void> _onSend(ChatMessage message) async {
    _history.add(LlmUserText(_toPromptText(message)));
    await loop.run(history: _history, onText: transport.addChunk);
  }

  /// Traduce il messaggio del package in testo per il modello.
  ///
  /// Un tap su una card non arriva come testo ma come `UiInteractionPart`:
  /// va srotolato, altrimenti il modello riceve un messaggio vuoto.
  static String _toPromptText(ChatMessage message) {
    final interactions = message.parts
        .map((part) => part.asUiInteractionPart)
        .nonNulls
        .map((part) => part.interaction);

    return [
      if (message.text.isNotEmpty) message.text,
      for (final interaction in interactions)
        'L utente ha interagito con la UI: $interaction',
    ].join('\n');
  }

  void dispose() {
    conversation.dispose();
    transport.dispose();
    repository.dispose();
  }
}
