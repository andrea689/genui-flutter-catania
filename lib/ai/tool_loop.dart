import 'llm_gateway.dart';

/// Esegue un tool e restituisce il payload JSON da rimandare al modello.
typedef ToolHandler =
    Future<Map<String, Object?>> Function(Map<String, Object?> args);

/// Il modello ha continuato a chiedere tool oltre il limite consentito.
class ToolLoopExhausted implements Exception {
  const ToolLoopExhausted(this.maxRounds);

  final int maxRounds;

  @override
  String toString() =>
      'ToolLoopExhausted: il modello ha chiesto tool per $maxRounds round '
      'senza produrre una risposta finale.';
}

/// Il cuore del rischio R1.
///
/// Gestisce il giro: il modello chiede una function call, noi eseguiamo il
/// tool, rimandiamo il risultato, e il round successivo produce i chunk A2UI.
///
/// Il punto chiave, verificato sul package: l'A2UI **non** viaggia come
/// function call ma come blocchi JSON dentro il flusso di testo (vedi
/// `PromptFragments.uiGenerationRestriction`). I due canali sono ortogonali,
/// quindi function calling e streaming A2UI convivono senza conflitti.
class ToolLoop {
  const ToolLoop({
    required this.gateway,
    required this.tools,
    this.maxRounds = 4,
  });

  /// Da dove arrivano i round del modello.
  final LlmGateway gateway;

  /// Gli handler eseguibili, per nome.
  final Map<String, ToolHandler> tools;

  /// Numero massimo di round con function call prima di arrendersi.
  final int maxRounds;

  /// Fa girare il loop finche' il modello smette di chiedere tool.
  ///
  /// [onText] riceve ogni delta di testo appena arriva: e' il canale su cui va
  /// collegato `A2uiTransportAdapter.addChunk`.
  Future<void> run({
    required List<LlmMessage> history,
    required void Function(String text) onText,
  }) async {
    for (var round = 0; round < maxRounds; round++) {
      final calls = <LlmToolCall>[];

      await for (final event in gateway.streamTurn(history)) {
        switch (event) {
          case LlmTextDelta(:final text):
            onText(text);
          case LlmToolCallEvent(:final call):
            calls.add(call);
        }
      }

      // Nessun tool richiesto: il round appena streammato era la risposta
      // finale, A2UI compreso.
      if (calls.isEmpty) return;

      history
        ..add(LlmModelCalls(calls))
        ..add(LlmToolResults(await _executeAll(calls)));
    }
    throw ToolLoopExhausted(maxRounds);
  }

  Future<List<LlmToolResult>> _executeAll(List<LlmToolCall> calls) async {
    return Future.wait(calls.map(_executeOne));
  }

  Future<LlmToolResult> _executeOne(LlmToolCall call) async {
    final handler = tools[call.name];
    if (handler == null) {
      return LlmToolResult(
        name: call.name,
        id: call.id,
        payload: {'error': 'Tool sconosciuto: ${call.name}'},
      );
    }
    try {
      return LlmToolResult(
        name: call.name,
        id: call.id,
        payload: await handler(call.args),
      );
    } on Object catch (error) {
      // Un tool che esplode non deve uccidere la conversazione: il modello
      // riceve l'errore e puo' spiegarlo all'utente.
      return LlmToolResult(
        name: call.name,
        id: call.id,
        payload: {'error': error.toString()},
      );
    }
  }
}
