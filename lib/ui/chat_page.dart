import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

import '../bloc/conversation_bloc.dart';

/// La schermata della demo: una chat in cui le risposte sono UI.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _input.text.trim();
    if (text.isEmpty) return;
    context.read<ConversationBloc>().add(
      EtnaConversationEvent.messageSent(text),
    );
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ConversationBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etna Assistant'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'La UI la compone il modello, dal catalogo',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<ConversationBloc, EtnaConversationState>(
              listener: (context, state) {
                if (state is ConversationErrorState) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(state.message)));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.animateTo(
                      _scroll.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
              builder: (context, state) {
                if (state is ConversationInitial) {
                  return _Suggestions(onPick: _send);
                }
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    if (state.assistantText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          state.assistantText,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    // Ogni surface e' una risposta composta dal modello.
                    for (final surfaceId in state.activeSurfaceIds)
                      Surface(
                        key: ValueKey(surfaceId),
                        surfaceContext: bloc.agent.controller.contextFor(
                          surfaceId,
                        ),
                      ),
                    if (state.isThinking) const _Thinking(),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Chiedi dell attivita sismica dell Etna',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: _send, child: const Text('Invia')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// Le tre domande della demo, a portata di tap: sul palco non si digita.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final void Function(String question) onPick;

  static const List<String> _questions = [
    'Cosa e successo sull Etna questa settimana?',
    'Dimmi della scossa piu forte',
    'Confronta con il mese scorso',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terrain, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Etna Assistant', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Stessi dati, tre presentazioni diverse',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            for (final question in _questions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => onPick(question),
                  child: Text(question),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
