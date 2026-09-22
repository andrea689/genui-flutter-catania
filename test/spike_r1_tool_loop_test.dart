// SPIKE R1 — function calling + streaming A2UI convivono?
//
// Il fake sostituisce SOLO il modello. Transport, SurfaceController,
// Conversation e il parser A2UI sono quelli veri del package genui 0.10.3.
// Se la surface viene creata, il giro completo regge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/ai/tool_loop.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Un modello finto scriptato: ogni elemento e' un round.
class FakeGateway implements LlmGateway {
  FakeGateway(this.rounds);

  final List<List<LlmEvent>> rounds;
  final List<List<LlmMessage>> seenHistories = [];
  int _round = 0;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    seenHistories.add(List.of(history));
    final events = rounds[_round++];
    for (final event in events) {
      // Forza un tick di event loop fra i chunk: simula lo streaming reale.
      await Future<void>.delayed(Duration.zero);
      yield event;
    }
  }
}

const _catalogId = 'etna.demo:spike';

final _spikeCatalog = Catalog([
  CatalogItem(
    name: 'QuakeCard',
    dataSchema: S.object(
      properties: {'place': S.string(), 'mag': S.number()},
      required: ['place', 'mag'],
    ),
    widgetBuilder: (itemContext) {
      final data = itemContext.data as Map<String, Object?>;
      return Text('${data['place']} M${data['mag']}');
    },
  ),
], catalogId: _catalogId);

void main() {
  test('R1: il modello chiede un tool, riceve i dati e poi streamma A2UI '
      'che crea davvero una surface', () async {
    // Round 1: il modello chiede la function call, senza testo A2UI.
    // Round 2: dopo il risultato del tool, streamma l'A2UI a pezzi.
    final gateway = FakeGateway([
      [
        const LlmTextDelta('Controllo i dati INGV. '),
        const LlmToolCallEvent(
          LlmToolCall(
            name: 'searchEarthquakes',
            args: {'minMagnitude': 3.0},
            id: 'call-1',
          ),
        ),
      ],
      [
        // A2UI spezzato a meta' di un token JSON, apposta.
        const LlmTextDelta('Ecco la scossa piu\' forte.\n```json\n'),
        const LlmTextDelta('{"version":"v0.9","createSurface":'),
        const LlmTextDelta('{"surfaceId":"s1","catalogId":"$_catalogId"}}'),
        const LlmTextDelta('\n```\n```json\n{"version":"v0.9",'),
        const LlmTextDelta('"updateComponents":{"surfaceId":"s1",'),
        const LlmTextDelta('"components":[{"id":"root",'),
        const LlmTextDelta(
          '"component":"QuakeCard","place":"Zafferana Etnea (CT)",'
          '"mag":3.4}]}}',
        ),
        const LlmTextDelta('\n```\n'),
      ],
    ]);

    var toolCalls = 0;
    final loop = ToolLoop(
      gateway: gateway,
      tools: {
        'searchEarthquakes': (args) async {
          toolCalls++;
          return {
            'events': [
              {'place': 'Zafferana Etnea (CT)', 'mag': 3.4},
            ],
          };
        },
      },
    );

    final controller = SurfaceController(catalogs: [_spikeCatalog]);
    final transport = A2uiTransportAdapter(onSend: (_) async {});
    final conversation = Conversation(
      controller: controller,
      transport: transport,
    );
    addTearDown(() {
      conversation.dispose();
      transport.dispose();
    });

    final surfaceAdded = <String>[];
    final chatText = StringBuffer();
    final errors = <Object>[];
    conversation.events.listen((event) {
      switch (event) {
        case ConversationSurfaceAdded(:final surfaceId):
          surfaceAdded.add(surfaceId);
        case ConversationContentReceived(:final text):
          chatText.write(text);
        case ConversationError(:final error):
          errors.add(error);
        default:
          break;
      }
    });

    final history = <LlmMessage>[
      const LlmUserText('dimmi della scossa piu\' forte'),
    ];

    // Questo e' esattamente il corpo di A2uiTransportAdapter.onSend.
    await loop.run(history: history, onText: transport.addChunk);

    // Lascia sfilare gli stream asincroni.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(toolCalls, 1, reason: 'il tool deve essere stato eseguito');
    expect(gateway.seenHistories.length, 2, reason: 'due round');

    // Il secondo round deve aver visto la call + il risultato del tool.
    final secondHistory = gateway.seenHistories[1];
    expect(secondHistory.whereType<LlmModelCalls>(), hasLength(1));
    expect(secondHistory.whereType<LlmToolResults>(), hasLength(1));

    expect(errors, isEmpty, reason: 'nessun errore di parsing A2UI');
    expect(surfaceAdded, [
      's1',
    ], reason: 'la surface deve nascere dai chunk A2UI streammati');

    // Il testo in chiaro arriva come testo, il JSON no.
    expect(chatText.toString(), contains('Controllo i dati INGV.'));
    expect(chatText.toString(), contains('Ecco la scossa'));
    expect(chatText.toString(), isNot(contains('createSurface')));

    // E la surface contiene davvero il componente del catalogo.
    final definition = controller.contextFor('s1').definition.value;
    expect(definition, isNotNull);
    expect(definition!.components['root']?.type, 'QuakeCard');
    expect(
      definition.components['root']?.properties['place'],
      'Zafferana Etnea (CT)',
    );
  });

  test('R1: il loop si ferma e segnala se il modello cicla sui tool', () async {
    final gateway = FakeGateway(
      List.generate(
        4,
        (_) => [
          const LlmToolCallEvent(
            LlmToolCall(name: 'searchEarthquakes', args: {}),
          ),
        ],
      ),
    );
    final loop = ToolLoop(
      gateway: gateway,
      tools: {
        'searchEarthquakes': (_) async => {'events': <Object>[]},
      },
      maxRounds: 4,
    );

    await expectLater(
      loop.run(history: [const LlmUserText('x')], onText: (_) {}),
      throwsA(isA<ToolLoopExhausted>()),
    );
  });

  test('R1: un tool che esplode non uccide la conversazione', () async {
    final gateway = FakeGateway([
      [
        const LlmToolCallEvent(
          LlmToolCall(name: 'searchEarthquakes', args: {}),
        ),
      ],
      [const LlmTextDelta('INGV non risponde, riprova piu\' tardi.')],
    ]);
    final loop = ToolLoop(
      gateway: gateway,
      tools: {'searchEarthquakes': (_) async => throw Exception('INGV 503')},
    );

    final text = StringBuffer();
    await loop.run(history: [const LlmUserText('x')], onText: text.write);

    final results = gateway.seenHistories[1].whereType<LlmToolResults>().single;
    expect(results.results.single.payload['error'], contains('INGV 503'));
    expect(text.toString(), contains('INGV non risponde'));
  });
}
