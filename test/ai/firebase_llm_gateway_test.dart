import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/firebase_llm_gateway.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';

/// Questi test bloccano una regressione che si manifesta **solo** contro l'API
/// vera, e quindi nel momento peggiore: durante la demo.
///
/// Gemini 3.x accetta i ruoli 'user' e 'model'. Non accetta 'function':
///
///   Role 'function' is not supported. Please use a valid role:
///   SYSTEM, SYSTEM_1, USER, ASSISTANT, DEVELOPER, CONTEXT, ...
///
/// `Content.functionResponses()` di firebase_ai 4.0.0 produce pero' proprio
/// 'function'. Se qualcuno "semplifica" [FirebaseLlmGateway.toContent]
/// tornando a usare quell'helper, il tool loop si rompe al secondo round.
void main() {
  group('FirebaseLlmGateway.toContent', () {
    test('il testo utente parte come ruolo user', () {
      final content = FirebaseLlmGateway.toContent(
        const LlmUserText('cosa e successo sull Etna questa settimana?'),
      );

      expect(content.role, 'user');
      expect(content.parts.single, isA<TextPart>());
    });

    test('le function call del modello partono come ruolo model', () {
      final content = FirebaseLlmGateway.toContent(
        const LlmModelCalls([
          LlmToolCall(
            name: 'searchEarthquakes',
            args: {'daysBack': 7},
            id: 'call-1',
          ),
        ]),
      );

      expect(content.role, 'model');
      expect(content.parts.single, isA<FunctionCall>());
    });

    test(
      "i risultati dei tool partono come ruolo user, MAI 'function'",
      () {
        final content = FirebaseLlmGateway.toContent(
          const LlmToolResults([
            LlmToolResult(
              name: 'searchEarthquakes',
              payload: {'events': <Object?>[]},
              id: 'call-1',
            ),
          ]),
        );

        expect(
          content.role,
          isNot('function'),
          reason: "Gemini 3.x rifiuta il ruolo 'function': "
              'non usare Content.functionResponses() di firebase_ai.',
        );
        expect(content.role, 'user');
        expect(content.parts.single, isA<FunctionResponse>());
      },
    );

    test('piu risultati finiscono in un solo turno user', () {
      final content = FirebaseLlmGateway.toContent(
        const LlmToolResults([
          LlmToolResult(name: 'a', payload: {}, id: '1'),
          LlmToolResult(name: 'b', payload: {}, id: '2'),
        ]),
      );

      expect(content.role, 'user');
      expect(content.parts, hasLength(2));
    });

    test('ogni ruolo prodotto e fra quelli che il modello accetta', () {
      // La lista viene dal messaggio di errore dell'API, normalizzata.
      const accettati = {'system', 'user', 'model', 'assistant', 'developer'};

      final messaggi = <LlmMessage>[
        const LlmUserText('x'),
        const LlmModelCalls([LlmToolCall(name: 'n', args: {})]),
        const LlmToolResults([LlmToolResult(name: 'n', payload: {})]),
      ];

      for (final messaggio in messaggi) {
        final role = FirebaseLlmGateway.toContent(messaggio).role;
        expect(
          accettati,
          contains(role),
          reason: 'ruolo non accettato da Gemini 3.x: $role',
        );
      }
    });
  });
}
