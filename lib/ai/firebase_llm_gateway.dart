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
      history.map(_toContent),
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

  static Content _toContent(LlmMessage message) => switch (message) {
    LlmUserText(:final text) => Content.text(text),
    LlmModelCalls(:final calls) => Content.model([
      for (final call in calls) FunctionCall(call.name, call.args, id: call.id),
    ]),
    LlmToolResults(:final results) => Content.functionResponses([
      for (final result in results)
        FunctionResponse(result.name, result.payload, id: result.id),
    ]),
  };
}
