import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/etna_agent.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/ai/llm_provider.dart';
import 'package:genui_flutter_catania/ai/response_mode.dart';
import 'package:genui_flutter_catania/catalog/etna_theme.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';
import 'package:genui_flutter_catania/ui/etna_home.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _question = 'Cosa è successo sull\'Etna questa settimana?';

/// Always replies with the same text.
class _ReplyGateway implements LlmGateway {
  const _ReplyGateway(this.reply);

  final String reply;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    await Future<void>.delayed(Duration.zero);
    yield LlmTextDelta(reply);
  }
}

/// An INGV client that remembers whether it was closed: the sign that the
/// agent has been released.
class _TrackingClient extends MockClient {
  _TrackingClient() : super((_) async => http.Response('', 204));

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  late List<(LlmProvider, ResponseMode)> created;
  late List<_TrackingClient> clients;

  setUp(() {
    created = [];
    clients = [];
  });

  /// Fake agents, one per provider and mode: EtnaAgent.firebase needs
  /// Firebase.
  EtnaAgent createAgent(LlmProvider provider, ResponseMode mode) {
    created.add((provider, mode));
    final client = _TrackingClient();
    clients.add(client);
    return EtnaAgent.custom(
      catalog: mode.catalog,
      gateway: _ReplyGateway('Risposta da ${provider.label}.'),
      repository: IngvRepository(client: client),
    );
  }

  Future<void> pumpHome(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: EtnaTheme.dark,
      home: EtnaHome(createAgent: createAgent),
    ),
  );

  Future<void> choose(WidgetTester tester, LlmProvider provider) async {
    await tester.tap(find.byType(PopupMenuButton<LlmProvider>));
    await tester.pumpAndSettle();
    // On the menu item, not on its Text: the text doesn't receive taps.
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<LlmProvider>, provider.label),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseMode(WidgetTester tester, ResponseMode mode) async {
    await tester.tap(find.byType(PopupMenuButton<ResponseMode>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<ResponseMode>, mode.label),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('parte da Gemini, con la spunta nel menu', (tester) async {
    await pumpHome(tester);
    expect(created, [(LlmProvider.gemini, ResponseMode.etna)]);

    await tester.tap(find.byType(PopupMenuButton<LlmProvider>));
    await tester.pumpAndSettle();

    final items = tester.widgetList<CheckedPopupMenuItem<LlmProvider>>(
      find.byType(CheckedPopupMenuItem<LlmProvider>),
    );
    expect(
      {for (final item in items) item.value: item.checked},
      {LlmProvider.gemini: true, LlmProvider.local: false},
    );
  });

  testWidgets(
    'cambiare provider crea un agente nuovo, rilascia il vecchio e svuota la chat',
    (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text(_question));
      await tester.pumpAndSettle();
      expect(find.text('Risposta da Gemini.'), findsOneWidget);

      await choose(tester, LlmProvider.local);

      expect(created, [
        (LlmProvider.gemini, ResponseMode.etna),
        (LlmProvider.local, ResponseMode.etna),
      ]);
      expect(clients.first.closed, isTrue);
      expect(find.text('Risposta da Gemini.'), findsNothing);
      // The three suggested questions again: the chat has started over.
      expect(find.text(_question), findsOneWidget);

      await tester.tap(find.text(_question));
      await tester.pumpAndSettle();
      expect(find.text('Risposta da Locale.'), findsOneWidget);
    },
  );

  testWidgets('scegliere il provider già attivo non tocca la chat', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.text(_question));
    await tester.pumpAndSettle();

    await choose(tester, LlmProvider.gemini);

    expect(created, [(LlmProvider.gemini, ResponseMode.etna)]);
    expect(find.text('Risposta da Gemini.'), findsOneWidget);
  });

  testWidgets('parte dal catalogo Etna, con la spunta e il sottotitolo', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(
      find.text('La UI la compone il modello, dal catalogo Etna'),
      findsOneWidget,
    );

    await tester.tap(find.byType(PopupMenuButton<ResponseMode>));
    await tester.pumpAndSettle();

    final items = tester.widgetList<CheckedPopupMenuItem<ResponseMode>>(
      find.byType(CheckedPopupMenuItem<ResponseMode>),
    );
    expect(
      {for (final item in items) item.value: item.checked},
      {
        ResponseMode.text: false,
        ResponseMode.basic: false,
        ResponseMode.etna: true,
      },
    );
  });

  testWidgets(
    'cambiare modalità crea un agente nuovo, svuota la chat e tiene il provider',
    (tester) async {
      await pumpHome(tester);
      await choose(tester, LlmProvider.local);
      await tester.tap(find.text(_question));
      await tester.pumpAndSettle();
      expect(find.text('Risposta da Locale.'), findsOneWidget);

      await chooseMode(tester, ResponseMode.text);

      expect(created.last, (LlmProvider.local, ResponseMode.text));
      expect(clients[1].closed, isTrue);
      expect(find.text('Risposta da Locale.'), findsNothing);
      expect(find.text(_question), findsOneWidget);
      expect(
        find.text('Solo testo: il modello non ha un catalogo'),
        findsOneWidget,
      );

      await chooseMode(tester, ResponseMode.basic);

      expect(created.last, (LlmProvider.local, ResponseMode.basic));
      expect(
        find.text('La UI la compone il modello, dal catalogo base'),
        findsOneWidget,
      );
    },
  );
}
