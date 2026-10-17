import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:genui/genui.dart';

import '../bloc/conversation_bloc.dart';

/// The demo screen: a chat where the replies are UI.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.actions = const [],
    this.subtitle = 'La UI la compone il modello, dal catalogo',
  });

  /// The buttons on the right of the AppBar, chosen by whoever mounts the
  /// page: `EtnaHome` puts the mode and provider pickers there.
  final List<Widget> actions;

  /// The line under the title: `EtnaHome` uses it to show which version of
  /// the app the audience is looking at.
  final String subtitle;

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
        actions: widget.actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.subtitle, style: const TextStyle(fontSize: 12)),
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
                    for (final turn in state.turns) ...[
                      if (turn.userMessage case final message?)
                        _UserMessage(message),
                      // The A2UI parser releases the newlines between JSON
                      // blocks late: leading and trailing whitespace isn't
                      // content.
                      if (turn.text.trim() case final text when text.isNotEmpty)
                        _AssistantMessage(text),
                      // Each surface is a reply composed by the model.
                      for (final surfaceId in turn.surfaceIds)
                        _SurfaceFrame(
                          surfaceId: surfaceId,
                          child: Surface(
                            key: ValueKey(surfaceId),
                            surfaceContext: bloc.agent.controller.contextFor(
                              surfaceId,
                            ),
                          ),
                        ),
                    ],
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
                        hintText: 'Chiedi dell\'attività sismica dell\'Etna',
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

/// The user's message, on the right as in any chat.
class _UserMessage extends StatelessWidget {
  const _UserMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.only(left: 48, top: 8, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// The model's plain text, on the left. It's markdown: Gemini uses it for
/// bold text and lists.
class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet.fromTheme(
            theme,
          ).copyWith(p: theme.textTheme.bodyLarge),
        ),
      ),
    );
  }
}

/// The frame around a surface: everything inside it was composed by the model
/// with the catalog widgets.
///
/// It makes the boundary between the two channels visible: plain text
/// outside, A2UI inside. Without the frame a catalog `Text` looks identical to
/// the chat text.
class _SurfaceFrame extends StatelessWidget {
  const _SurfaceFrame({required this.surfaceId, required this.child});

  final String surfaceId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.widgets_outlined, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SURFACE · $surfaceId',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
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

/// The demo's three questions, one tap away: nobody types on stage.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final void Function(String question) onPick;

  static const List<String> _questions = [
    'Cosa è successo sull\'Etna questa settimana?',
    'Dimmi della scossa più forte',
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
