// Il giro completo della demo, con un modello finto ma tutto il resto vero:
// catalogo reale, transport reale, SurfaceController reale, bloc reale.
// L'unica cosa simulata e' Gemini (e la rete INGV).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/etna_agent.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/bloc/conversation_bloc.dart';
import 'package:genui_flutter_catania/catalog/etna_catalog.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _ingvResponse = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature",
  "properties":{"eventId":41287651,"time":"2026-09-18T03:14:22.180000",
                "magType":"Mw","mag":4.3,"place":"Zafferana Etnea (CT)"},
  "geometry":{"type":"Point","coordinates":[15.1053,37.6921,2.4]}}
]}
''';

class _ScriptedGateway implements LlmGateway {
  _ScriptedGateway(this.rounds);

  final List<List<LlmEvent>> rounds;
  final List<List<LlmMessage>> histories = [];
  int _index = 0;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    histories.add(List.of(history));
    for (final event in rounds[_index++]) {
      await Future<void>.delayed(Duration.zero);
      yield event;
    }
  }
}

EtnaAgent _agent(_ScriptedGateway gateway) => EtnaAgent.custom(
  catalog: EtnaCatalog.asCatalog(),
  gateway: gateway,
  repository: IngvRepository(
    client: MockClient((_) async => http.Response(_ingvResponse, 200)),
  ),
);

/// Il modello chiede il tool, poi compone una EventCard.
List<List<LlmEvent>> _eventCardScript() => [
  [
    const LlmToolCallEvent(
      LlmToolCall(
        name: 'searchEarthquakes',
        args: {'daysBack': 7, 'minMagnitude': 3.0},
        id: 'c1',
      ),
    ),
  ],
  [
    const LlmTextDelta('La scossa piu forte e stata a Zafferana Etnea.\n'),
    const LlmTextDelta('```json\n{"version":"v0.9","createSurface":'),
    const LlmTextDelta(
      '{"surfaceId":"s1","catalogId":"${EtnaCatalog.catalogId}"}}\n```\n',
    ),
    const LlmTextDelta('```json\n{"version":"v0.9","updateComponents":'),
    const LlmTextDelta('{"surfaceId":"s1","components":[{"id":"root",'),
    const LlmTextDelta('"component":"EventCard","event":{'),
    const LlmTextDelta(
      '"eventId":"41287651","time":"2026-09-18T03:14:22Z",'
      '"magnitude":4.3,"magnitudeType":"Mw",'
      '"place":"Zafferana Etnea (CT)","latitude":37.6921,'
      '"longitude":15.1053,"depthKm":2.4}}]}}\n```\n',
    ),
  ],
];

void main() {
  group('ConversationBloc', () {
    test('parte in stato initial', () {
      final gateway = _ScriptedGateway([]);
      final agent = _agent(gateway);
      addTearDown(agent.dispose);
      final bloc = ConversationBloc(agent);
      addTearDown(bloc.close);

      expect(bloc.state, isA<ConversationInitial>());
      expect(bloc.state.activeSurfaceIds, isEmpty);
    });

    test(
      'una domanda produce il tool INGV, poi una surface con EventCard',
      () async {
        final gateway = _ScriptedGateway(_eventCardScript());
        final agent = _agent(gateway);
        addTearDown(agent.dispose);
        final bloc = ConversationBloc(agent);
        addTearDown(bloc.close);

        bloc.add(
          const EtnaConversationEvent.messageSent(
            'dimmi della scossa piu forte',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Il tool e' stato chiamato e il risultato e' tornato al modello.
        expect(gateway.histories, hasLength(2));
        final toolResults = gateway.histories[1]
            .whereType<LlmToolResults>()
            .single;
        final payload = toolResults.results.single.payload;
        expect(payload['count'], 1);
        expect(
          (payload['events']! as List).first,
          containsPair('place', 'Zafferana Etnea (CT)'),
        );

        // E la surface e' arrivata fino allo stato del bloc.
        expect(bloc.state, isA<ConversationSurfaces>());
        expect(bloc.state.activeSurfaceIds, ['s1']);
        expect(bloc.state.assistantText, contains('Zafferana Etnea'));
        expect(bloc.state.assistantText, isNot(contains('createSurface')));
        expect(bloc.state.isThinking, isFalse);

        // Il componente e' davvero quello del catalogo.
        final definition = agent.controller.contextFor('s1').definition.value;
        expect(definition!.components['root']!.type, 'EventCard');
      },
    );

    blocTest<ConversationBloc, EtnaConversationState>(
      'passa da thinking a surfaces',
      build: () {
        final gateway = _ScriptedGateway(_eventCardScript());
        return ConversationBloc(_agent(gateway));
      },
      act: (bloc) =>
          bloc.add(const EtnaConversationEvent.messageSent('che succede?')),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state, isA<ConversationSurfaces>());
      },
      tearDown: () {},
    );

    test('un errore del modello finisce in stato error', () async {
      final gateway = _ScriptedGateway([]);
      final agent = _agent(gateway);
      addTearDown(agent.dispose);
      final bloc = ConversationBloc(agent);
      addTearDown(bloc.close);

      // Lo script e' vuoto: streamTurn esplode con RangeError.
      bloc.add(const EtnaConversationEvent.messageSent('boom'));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(bloc.state, isA<ConversationErrorState>());
      expect((bloc.state as ConversationErrorState).message, isNotEmpty);
    });

    test('le surface sopravvivono al turno successivo', () async {
      final script = _eventCardScript()
        ..add([
          const LlmTextDelta('Ecco anche la mappa.\n'),
          const LlmTextDelta('```json\n{"version":"v0.9","createSurface":'),
          const LlmTextDelta(
            '{"surfaceId":"s2","catalogId":"${EtnaCatalog.catalogId}"}}\n```\n',
          ),
          const LlmTextDelta(
            '```json\n{"version":"v0.9","updateComponents":'
            '{"surfaceId":"s2","components":[{"id":"root",'
            '"component":"MapCard","events":[]}]}}\n```\n',
          ),
        ]);

      final gateway = _ScriptedGateway(script);
      final agent = _agent(gateway);
      addTearDown(agent.dispose);
      final bloc = ConversationBloc(agent);
      addTearDown(bloc.close);

      bloc.add(const EtnaConversationEvent.messageSent('scossa piu forte'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      bloc.add(const EtnaConversationEvent.messageSent('e la mappa?'));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(bloc.state.activeSurfaceIds, ['s1', 's2']);

      // Lo storico e' cumulativo: e' la memoria multi-turno.
      final lastHistory = gateway.histories.last;
      expect(lastHistory.whereType<LlmUserText>(), hasLength(2));
    });
  });
}
