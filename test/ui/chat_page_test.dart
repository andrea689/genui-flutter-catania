import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_flutter_catania/ai/etna_agent.dart';
import 'package:genui_flutter_catania/ai/llm_gateway.dart';
import 'package:genui_flutter_catania/bloc/conversation_bloc.dart';
import 'package:genui_flutter_catania/catalog/etna_catalog.dart';
import 'package:genui_flutter_catania/catalog/etna_theme.dart';
import 'package:genui_flutter_catania/data/ingv_repository.dart';
import 'package:genui_flutter_catania/ui/chat_page.dart';

/// Risponde a ogni domanda con il testo del round successivo.
class _ScriptedGateway implements LlmGateway {
  _ScriptedGateway(this.replies);

  final List<String> replies;
  int _index = 0;

  @override
  Stream<LlmEvent> streamTurn(List<LlmMessage> history) async* {
    await Future<void>.delayed(Duration.zero);
    yield LlmTextDelta(replies[_index++]);
  }
}

void main() {
  testWidgets('i messaggi dell utente restano in chat sopra la risposta', (
    tester,
  ) async {
    final agent = EtnaAgent.custom(
      catalog: EtnaCatalog.asCatalog(),
      gateway: _ScriptedGateway([
        'Sei giorni tranquilli.',
        'La piu forte e stata una 4.3.',
      ]),
      repository: IngvRepository(),
    );
    addTearDown(agent.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: EtnaTheme.dark,
        home: BlocProvider(
          create: (_) => ConversationBloc(agent),
          child: const ChatPage(),
        ),
      ),
    );

    await tester.tap(find.text('Cosa e successo sull Etna questa settimana?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'e la scossa piu forte?');
    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();

    // Domande e risposte, nell'ordine in cui sono avvenute.
    final texts = [
      'Cosa e successo sull Etna questa settimana?',
      'Sei giorni tranquilli.',
      'e la scossa piu forte?',
      'La piu forte e stata una 4.3.',
    ];
    final tops = [
      for (final text in texts) tester.getTopLeft(find.text(text)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));

    // Lo spinner si spegne anche se la risposta e' solo testo.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
