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

  /// I modelli "thinking" di Gemini 3 allegano alle function call una
  /// `thought_signature` che va rimandata indietro nel round successivo:
  ///
  ///   Function call is missing a thought_signature in functionCall parts.
  ///   This is required for tools to work correctly.
  ///
  /// In firebase_ai 4.0.0 quella signature e' un campo privato senza getter, e
  /// `FunctionCall(...)` la forza a null. Quindi l'unico modo di conservarla e'
  /// **non ricostruire l'oggetto**: questi test lo verificano per identita'.
  group('thought signature', () {
    test('la function call originale torna indietro tale e quale', () {
      final originale = FunctionCall(
        'searchEarthquakes',
        const {'daysBack': 7},
        id: 'call-1',
      );

      final content = FirebaseLlmGateway.toContent(
        LlmModelCalls([
          LlmToolCall(
            name: originale.name,
            args: originale.args,
            id: originale.id,
            raw: originale,
          ),
        ]),
      );

      expect(
        identical(content.parts.single, originale),
        isTrue,
        reason: 'la Part va rimandata verbatim: ricostruirla perde la '
            'thought_signature, che e privata e non e leggibile.',
      );
    });

    test('senza raw ricostruisce, cosi i test col fake continuano a girare', () {
      final content = FirebaseLlmGateway.toContent(
        const LlmModelCalls([
          LlmToolCall(name: 'searchEarthquakes', args: {'daysBack': 7}),
        ]),
      );

      final part = content.parts.single as FunctionCall;
      expect(part.name, 'searchEarthquakes');
      expect(part.args, const {'daysBack': 7});
    });

    test('ogni call porta con se il proprio raw, senza mescolarli', () {
      final prima = FunctionCall('a', const {}, id: '1');
      final seconda = FunctionCall('b', const {}, id: '2');

      final content = FirebaseLlmGateway.toContent(
        LlmModelCalls([
          LlmToolCall(name: 'a', args: const {}, id: '1', raw: prima),
          LlmToolCall(name: 'b', args: const {}, id: '2', raw: seconda),
        ]),
      );

      expect(identical(content.parts[0], prima), isTrue);
      expect(identical(content.parts[1], seconda), isTrue);
    });
  });
}
