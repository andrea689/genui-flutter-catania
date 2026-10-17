// The demo's full round trip, with a fake model but everything else real:
// real catalog, real transport, real SurfaceController, real bloc.
// The only things simulated are Gemini (and the INGV network).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
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

/// A model that doesn't respond until the test releases it: a hung Gemini.
class _HangingGateway implements LlmGateway {
  final Completer<void> release = Completer<void>();

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    await release.future;
    yield const LlmTextDelta('Risposta arrivata tardi.');
  }
}

/// A hung model that answers each round only when the test releases that
/// specific round: needed to have two requests in flight at once.
class _ManualGateway implements LlmGateway {
  final List<Completer<void>> rounds = [];

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    final release = Completer<void>();
    rounds.add(release);
    await release.future;
    yield const LlmTextDelta('Risposta arrivata tardi.');
  }
}

/// An INGV client that remembers whether it was closed: the sign that the
/// agent has been released.
class _TrackingClient extends MockClient {
  _TrackingClient() : super((_) async => http.Response(_ingvResponse, 200));

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

EtnaAgent _trackedAgent(LlmGateway gateway, _TrackingClient client) =>
    EtnaAgent.custom(
      catalog: EtnaCatalog.asCatalog(),
      gateway: gateway,
      repository: IngvRepository(client: client),
    );

EtnaAgent _agent(_ScriptedGateway gateway) => EtnaAgent.custom(
  catalog: EtnaCatalog.asCatalog(),
  gateway: gateway,
  repository: IngvRepository(
    client: MockClient((_) async => http.Response(_ingvResponse, 200)),
  ),
);

/// The model asks for the tool, then composes an EventCard.
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
    const LlmTextDelta('La scossa più forte è stata a Zafferana Etnea.\n'),
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

/// Waits for the model to finish replying: the [genui.Conversation]'s
/// `isWaiting` goes to true and then back to false.
///
/// Better than a `Future.delayed`: the fake round trip goes through the tool
/// loop, the A2UI parser and the bloc, and on a busy CPU no fixed delay is
/// guaranteed to be enough.
Future<void> _untilReplied(EtnaAgent agent) async {
  final state = agent.conversation.state;
  final replied = Completer<void>();
  var started = state.value.isWaiting;
  void listener() {
    if (state.value.isWaiting) {
      started = true;
    } else if (started && !replied.isCompleted) {
      replied.complete();
    }
  }

  state.addListener(listener);
  try {
    await replied.future.timeout(const Duration(seconds: 5));
  } finally {
    state.removeListener(listener);
  }
  // The bloc receives the end of the reply as an event: let it process it.
  await pumpEventQueue();
}

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
            'dimmi della scossa più forte',
          ),
        );
        await _untilReplied(agent);

        // The tool was called and its result went back to the model.
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

        // And the surface made it all the way to the bloc state.
        expect(bloc.state, isA<ConversationSurfaces>());
        expect(bloc.state.activeSurfaceIds, ['s1']);
        expect(bloc.state.assistantText, contains('Zafferana Etnea'));
        expect(bloc.state.assistantText, isNot(contains('createSurface')));
        expect(bloc.state.isThinking, isFalse);

        // The component really is the catalog one.
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
      act: (bloc) async {
        bloc.add(const EtnaConversationEvent.messageSent('che succede?'));
        await _untilReplied(bloc.agent);
      },
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

      // The script is empty: streamTurn throws a RangeError.
      bloc.add(const EtnaConversationEvent.messageSent('boom'));
      await _untilReplied(agent);

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

      bloc.add(const EtnaConversationEvent.messageSent('scossa più forte'));
      await _untilReplied(agent);
      bloc.add(const EtnaConversationEvent.messageSent('e la mappa?'));
      await _untilReplied(agent);

      expect(bloc.state.activeSurfaceIds, ['s1', 's2']);

      // The history is cumulative: it's the multi-turn memory.
      final lastHistory = gateway.histories.last;
      expect(lastHistory.whereType<LlmUserText>(), hasLength(2));
    });

    test(
      'i messaggi dell\'utente restano nella chat, ognuno col suo giro',
      () async {
        final script = _eventCardScript()
          ..add([
            const LlmTextDelta('Ecco anche la mappa.\n'),
            const LlmTextDelta(
              '```json\n{"version":"v0.9","createSurface":'
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

        bloc.add(const EtnaConversationEvent.messageSent('scossa più forte'));
        await _untilReplied(agent);
        bloc.add(const EtnaConversationEvent.messageSent('e la mappa?'));
        await _untilReplied(agent);

        final turns = bloc.state.turns;
        expect(turns.map((turn) => turn.userMessage), [
          'scossa più forte',
          'e la mappa?',
        ]);
        // Text and surfaces sit under the question they answer.
        expect(turns[0].text, contains('Zafferana Etnea'));
        expect(turns[0].surfaceIds, ['s1']);
        expect(turns[1].text, contains('Ecco anche la mappa'));
        expect(turns[1].text, isNot(contains('Zafferana')));
        expect(turns[1].surfaceIds, ['s2']);
      },
    );

    test(
      'il messaggio dell\'utente compare subito, prima della risposta',
      () async {
        final gateway = _ScriptedGateway(_eventCardScript());
        final agent = _agent(gateway);
        addTearDown(agent.dispose);
        final bloc = ConversationBloc(agent);
        addTearDown(bloc.close);

        final first = bloc.stream.first;
        bloc.add(
          const EtnaConversationEvent.messageSent(
            'dimmi della scossa più forte',
          ),
        );

        final state = await first;
        expect(state, isA<ConversationThinking>());
        expect(state.turns.single.userMessage, 'dimmi della scossa più forte');
        expect(state.turns.single.surfaceIds, isEmpty);

        // Let the round finish before tearDown.
        await _untilReplied(agent);
      },
    );

    test('una risposta di solo testo chiude il giro', () async {
      final gateway = _ScriptedGateway([
        [const LlmTextDelta('Chiedimi pure dell\'Etna.')],
      ]);
      final agent = _agent(gateway);
      addTearDown(agent.dispose);
      final bloc = ConversationBloc(agent);
      addTearDown(bloc.close);

      bloc.add(const EtnaConversationEvent.messageSent('ciao'));
      await _untilReplied(agent);

      expect(bloc.state.isThinking, isFalse);
      expect(bloc.state.activeSurfaceIds, isEmpty);
      expect(bloc.state.assistantText, 'Chiedimi pure dell\'Etna.');
    });

    test(
      'una richiesta partita da un tap apre un giro senza messaggio',
      () async {
        final script = _eventCardScript()
          ..add([const LlmTextDelta('Ecco il dettaglio.')]);
        final gateway = _ScriptedGateway(script);
        final agent = _agent(gateway);
        addTearDown(agent.dispose);
        final bloc = ConversationBloc(agent);
        addTearDown(bloc.close);

        bloc.add(const EtnaConversationEvent.messageSent('scossa più forte'));
        await _untilReplied(agent);

        // A tap on a card doesn't go through the bloc: the SurfaceController
        // calls sendRequest directly.
        await agent.conversation.sendRequest(
          genui.ChatMessage.user('L\'utente ha toccato la card'),
        );
        // sendRequest returns once the reply is done: only the bloc is left
        // to drain.
        await pumpEventQueue();

        final turns = bloc.state.turns;
        expect(turns, hasLength(2));
        expect(turns[1].userMessage, isNull);
        // The A2UI parser holds back the newline after the previous round's
        // last JSON block and releases it with this round's first chunk: the
        // UI trims it.
        expect(turns[1].text.trim(), 'Ecco il dettaglio.');
        expect(bloc.state.isThinking, isFalse);
      },
    );

    test('close rilascia l\'agente', () async {
      final client = _TrackingClient();
      final bloc = ConversationBloc(
        _trackedAgent(_ScriptedGateway([]), client),
      );

      await bloc.close();

      expect(client.closed, isTrue);
    });

    test('dispose due volte non esplode', () {
      final agent = _agent(_ScriptedGateway([]));

      agent.dispose();

      expect(agent.dispose, returnsNormally);
    });

    test(
      'con una risposta in corso l\'agente si rilascia a fine risposta',
      () async {
        final client = _TrackingClient();
        final gateway = _HangingGateway();
        final agent = _trackedAgent(gateway, client);
        final bloc = ConversationBloc(agent);

        bloc.add(const EtnaConversationEvent.messageSent('ciao'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(agent.conversation.state.value.isWaiting, isTrue);

        // The stage scenario: Gemini doesn't respond and we switch provider.
        await bloc.close();
        expect(client.closed, isFalse);

        // When the old request finishes, the agent is released without
        // errors: a ChangeNotifier assert would fail the test.
        gateway.release.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(client.closed, isTrue);
      },
    );

    test(
      'con due risposte in corso l\'agente aspetta anche la seconda',
      () async {
        final client = _TrackingClient();
        final gateway = _ManualGateway();
        final agent = _trackedAgent(gateway, client);
        final bloc = ConversationBloc(agent);

        // Gemini hangs, the presenter resends the question and then switches
        // provider: two requests in flight when the bloc closes.
        bloc.add(const EtnaConversationEvent.messageSent('ciao'));
        bloc.add(const EtnaConversationEvent.messageSent('ciao di nuovo'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(gateway.rounds, hasLength(2));

        await bloc.close();
        gateway.rounds[0].complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // isWaiting is back to false, but the second request is still running.
        expect(client.closed, isFalse);

        gateway.rounds[1].complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(client.closed, isTrue);
      },
    );
  });
}
