import 'package:firebase_ai/firebase_ai.dart';

import 'llm_gateway.dart';

/// Implementazione reale di [LlmGateway] sopra Firebase AI Logic.
///
/// Fa una cosa sola: tradurre i tipi neutri di `llm_gateway.dart` nei tipi di
/// `firebase_ai` e viceversa. Tutta la logica del giro sta in [ToolLoop], che
/// cosi' resta testabile senza rete.
class FirebaseLlmGateway implements LlmGateway {
  const FirebaseLlmGateway({required this.model, required this.tools});

  final GenerativeModel model;
  final List<Tool> tools;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    final stream = model.generateContentStream(
      history.map(toContent),
      tools: tools,
    );

    await for (final response in stream) {
      // I due canali sono distinti: il testo porta l'A2UI, le function call
      // portano le richieste di dati. Non si pestano i piedi.
      final text = response.text;
      if (text != null && text.isNotEmpty) {
        yield LlmTextDelta(text);
      }
      for (final call in response.functionCalls) {
        yield LlmToolCallEvent(
          LlmToolCall(name: call.name, args: call.args, id: call.id),
        );
      }
    }
  }

  /// Traduce un messaggio neutro in un [Content] di `firebase_ai`.
  ///
  /// Visibile per i test: e' l'unico punto che conosce i ruoli accettati dal
  /// modello, e sbagliarli si scopre solo contro l'API vera.
  static Content toContent(LlmMessage message) => switch (message) {
    LlmUserText(:final text) => Content.text(text),
    LlmModelCalls(:final calls) => Content.model([
      for (final call in calls) FunctionCall(call.name, call.args, id: call.id),
    ]),
    // ATTENZIONE: qui NON si usa Content.functionResponses(), che in
    // firebase_ai 4.0.0 hardcoda il ruolo 'function'. Gemini 3.x lo rifiuta:
    //   Role 'function' is not supported. Please use a valid role:
    //   SYSTEM, SYSTEM_1, USER, ASSISTANT, DEVELOPER, CONTEXT, ...
    // I ruoli validi sono 'user' e 'model': la risposta di un tool rientra
    // come turno 'user'. L'helper del package e' rimasto indietro sul modello.
    LlmToolResults(:final results) => Content('user', [
      for (final result in results)
        FunctionResponse(result.name, result.payload, id: result.id),
    ]),
  };
}
