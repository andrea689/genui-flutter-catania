import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ai/etna_agent.dart';
import '../ai/llm_provider.dart';
import '../ai/response_mode.dart';
import '../bloc/conversation_bloc.dart';
import '../bloc/llm_provider_cubit.dart';
import '../bloc/response_mode_cubit.dart';
import 'chat_page.dart';

/// Creates the agent for a provider and a response mode.
typedef AgentFactory =
    EtnaAgent Function(LlmProvider provider, ResponseMode mode);

/// The chat, with the provider and the response mode selected in the AppBar.
///
/// The conversation's `BlocProvider` is keyed by both: changing either one
/// unmounts the bloc, which releases its agent, and creates a new one. The
/// chat starts over empty. The two providers' histories never mix (the local
/// server's function calls lack the `thought_signature` Gemini 3 requires),
/// and neither do the modes': each one has its own system prompt.
class EtnaHome extends StatelessWidget {
  const EtnaHome({super.key, this.createAgent = EtnaAgent.forProvider});

  /// Injectable for tests: `EtnaAgent.firebase` needs Firebase initialized.
  final AgentFactory createAgent;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LlmProviderCubit()),
        BlocProvider(create: (_) => ResponseModeCubit()),
      ],
      child: Builder(
        builder: (context) {
          final provider = context.watch<LlmProviderCubit>().state;
          final mode = context.watch<ResponseModeCubit>().state;
          return BlocProvider(
            key: ValueKey((provider, mode)),
            create: (_) => ConversationBloc(createAgent(provider, mode)),
            child: ChatPage(
              subtitle: _subtitle(mode),
              actions: [
                const ResponseModeMenu(),
                // Debug only: the published site always uses Gemini.
                if (kDebugMode) const ProviderMenu(),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _subtitle(ResponseMode mode) => switch (mode) {
    ResponseMode.text => 'Solo testo: il modello non ha un catalogo',
    ResponseMode.basic => 'La UI la compone il modello, dal catalogo base',
    ResponseMode.etna => 'La UI la compone il modello, dal catalogo Etna',
  };
}

/// The menu for picking the response mode, with a check mark on the active
/// one.
///
/// Visible in release too: whoever opens the published demo can compare the
/// three versions like on stage.
class ResponseModeMenu extends StatelessWidget {
  const ResponseModeMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<ResponseModeCubit>().state;
    return PopupMenuButton<ResponseMode>(
      tooltip: 'Risposte: ${current.label}',
      icon: Icon(switch (current) {
        ResponseMode.text => Icons.notes,
        ResponseMode.basic => Icons.widgets_outlined,
        ResponseMode.etna => Icons.terrain,
      }),
      initialValue: current,
      onSelected: context.read<ResponseModeCubit>().select,
      itemBuilder: (_) => [
        for (final mode in ResponseMode.values)
          CheckedPopupMenuItem(
            value: mode,
            checked: mode == current,
            child: Text(mode.label),
          ),
      ],
    );
  }
}

/// The menu for picking the provider, with a check mark on the active one.
///
/// The icon changes with the provider: the presenter sees at a glance what
/// the demo is running on, without opening the menu.
class ProviderMenu extends StatelessWidget {
  const ProviderMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LlmProviderCubit>().state;
    return PopupMenuButton<LlmProvider>(
      tooltip: 'Provider: ${current.label}',
      icon: Icon(
        current == LlmProvider.local ? Icons.computer : Icons.cloud_outlined,
      ),
      initialValue: current,
      onSelected: context.read<LlmProviderCubit>().select,
      itemBuilder: (_) => [
        for (final provider in LlmProvider.values)
          CheckedPopupMenuItem(
            value: provider,
            checked: provider == current,
            child: Text(provider.label),
          ),
      ],
    );
  }
}
