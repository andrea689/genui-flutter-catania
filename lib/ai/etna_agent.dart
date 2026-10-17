import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:genui/genui.dart';

import '../data/ingv_repository.dart';
import 'etna_tools.dart';
import 'firebase_llm_gateway.dart';
import 'llm_gateway.dart';
import 'llm_provider.dart';
import 'local_llm_gateway.dart';
import 'logging_llm_gateway.dart';
import 'response_mode.dart';
import 'tool_loop.dart';

/// The Gemini model used by the demo.
///
/// Do NOT use `gemini-2.5-flash`: it shuts down on **October 16, 2026**, the
/// day before the talk. Every 2.5 model reaches end of life in October 2026.
///
/// The default is `gemini-3.5-flash`: stable since May 2026, supported until
/// at least May 2027.
///
/// **This is not the cautious choice out of inertia, it's a measured one.**
/// `gemini-3.8-flash` would be the default recommended by Firebase AI Logic
/// and follows instructions better, which matters for generative UI: it's
/// what keeps the widgets inside the schema. But it has been GA since
/// September 2, 2026, so it's taking all the load, and in testing it came
/// back **overloaded**.
///
/// A 503 "model is overloaded" during a live demo can't be fixed: it's out of
/// your hands and a hot reload won't make it go away. On stage, available
/// capacity beats benchmarks.
///
/// To try 3.8 without touching this file:
/// `--dart-define=GEMINI_MODEL=gemini-3.8-flash`
const String kGeminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-3.5-flash',
);

/// Wires the pieces together: catalog, system prompt, tools and transport.
class EtnaAgent {
  EtnaAgent._({
    required this.catalog,
    required this.controller,
    required this.transport,
    required this.conversation,
    required this.loop,
    required this.repository,
  });

  /// Builds the Gemini gateway.
  ///
  /// Kept separate from the factory because the verification tool in `tool/`
  /// wraps it to print what flows through the two channels.
  static LlmGateway buildFirebaseGateway({
    ResponseMode mode = ResponseMode.etna,
    FirebaseAI? ai,
  }) {
    final model = (ai ?? FirebaseAI.googleAI()).generativeModel(
      model: kGeminiModel,
      systemInstruction: Content.system(mode.systemPrompt),
      tools: EtnaTools.all,
    );

    return FirebaseLlmGateway(model: model, tools: EtnaTools.all);
  }

  /// Builds the agent on top of Firebase AI Logic.
  factory EtnaAgent.firebase({
    IngvRepository? repository,
    FirebaseAI? ai,
    ResponseMode mode = ResponseMode.etna,
  }) {
    final gateway = buildFirebaseGateway(mode: mode, ai: ai);
    return EtnaAgent.custom(
      catalog: mode.catalog,
      // In debug the model's response is printed to the console, to compare
      // it with what the UI shows.
      gateway: kLogLlm ? LoggingLlmGateway(gateway) : gateway,
      repository: repository ?? IngvRepository(),
    );
  }

  /// Builds the agent on top of the local provider.
  ///
  /// Same wiring as [EtnaAgent.firebase], only the gateway changes. The tools
  /// are the real ones: if the server asks for `searchEarthquakes`, the app
  /// actually queries INGV. The prompt and tool declarations are the same
  /// ones Gemini receives.
  factory EtnaAgent.local({
    IngvRepository? repository,
    ResponseMode mode = ResponseMode.etna,
  }) {
    final gateway = LocalLlmGateway(
      systemPrompt: mode.systemPrompt,
      tools: [EtnaTools.searchEarthquakes.toJson()],
    );
    return EtnaAgent.custom(
      catalog: mode.catalog,
      gateway: kLogLlm ? LoggingLlmGateway(gateway) : gateway,
      repository: repository ?? IngvRepository(),
    );
  }

  /// The agent for the provider and the mode selected in the AppBar.
  factory EtnaAgent.forProvider(
    LlmProvider provider, [
    ResponseMode mode = ResponseMode.etna,
  ]) => switch (provider) {
    LlmProvider.gemini => EtnaAgent.firebase(mode: mode),
    LlmProvider.local => EtnaAgent.local(mode: mode),
  };

  /// Builds the agent on top of any [LlmGateway].
  ///
  /// Exists for tests: the same wiring, with a fake model.
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
      onSend: (message) => agent._track(agent._onSend(message)),
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

  /// Handles function calling and A2UI streaming.
  final ToolLoop loop;

  final IngvRepository repository;

  /// The history lives here: it's the conversation's multi-turn memory.
  final List<LlmMessage> _history = [];

  bool _disposed = false;

  /// The body of `A2uiTransportAdapter.onSend`: the whole round trip in one
  /// function.
  Future<void> _onSend(ChatMessage message) async {
    _history.add(LlmUserText(_toPromptText(message)));
    await loop.run(history: _history, onText: transport.addChunk);
  }

  /// Turns the package's message into text for the model.
  ///
  /// A tap on a card doesn't arrive as text but as a `UiInteractionPart`: it
  /// has to be unpacked, otherwise the model receives an empty message.
  static String _toPromptText(ChatMessage message) {
    final interactions = message.parts
        .map((part) => part.asUiInteractionPart)
        .nonNulls
        .map((part) => part.interaction);

    return [
      if (message.text.isNotEmpty) message.text,
      for (final interaction in interactions)
        'L\'utente ha interagito con la UI: $interaction',
    ].join('\n');
  }

  /// Requests in flight, counted by [_track].
  int _pending = 0;

  /// The [ConversationBloc] has closed: the agent must be released as soon as
  /// it's idle.
  bool _releaseRequested = false;

  /// Counts in-flight requests, for [disposeWhenIdle].
  Future<void> _track(Future<void> request) async {
    _pending++;
    try {
      await request;
    } finally {
      _pending--;
      // Not right away: after onSend the Conversation still closes the
      // request and updates its state. A timer runs after it.
      if (_releaseRequested) Timer.run(_releaseIfIdle);
    }
  }

  /// Releases the agent as soon as it has no requests in flight.
  ///
  /// The [ConversationBloc] calls it when it closes. The typical case on
  /// stage: Gemini doesn't respond and we switch to the local provider. If
  /// the agent were released right away, the old request would update an
  /// already disposed Conversation when it finishes, tripping
  /// ChangeNotifier's assert.
  ///
  /// Requests are counted here rather than with the Conversation's
  /// `isWaiting`: that goes back to false when the first one ends, even if
  /// another is still in flight (a resent question, a tap on a card).
  ///
  /// If a request never finishes, the agent stays alive: a single leak.
  void disposeWhenIdle() {
    _releaseRequested = true;
    _releaseIfIdle();
  }

  void _releaseIfIdle() {
    if (_pending == 0) dispose();
  }

  /// Releases the conversation, the transport and the HTTP client.
  ///
  /// Idempotent: the [ConversationBloc] calls it when it closes, but tests
  /// and the tools in `tool/` that create the agent by hand call it again,
  /// and disposing the Conversation twice trips ChangeNotifier's assert.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    conversation.dispose();
    transport.dispose();
    repository.dispose();
  }
}
