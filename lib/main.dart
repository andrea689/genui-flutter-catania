import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai/etna_agent.dart';
import 'app/bootstrap.dart';
import 'bloc/conversation_bloc.dart';
import 'catalog/etna_theme.dart';
import 'ui/chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Se il bootstrap fallisce, il sito e' comunque linkato dal talk: meglio una
  // schermata che spiega il problema di una pagina bianca con un 403 nascosto
  // nei DevTools.
  try {
    await bootstrapFirebase();
  } on AppCheckMisconfigured catch (error) {
    runApp(EtnaAssistantApp(bootstrapError: error.message));
    return;
  }

  runApp(const EtnaAssistantApp());
}

class EtnaAssistantApp extends StatelessWidget {
  const EtnaAssistantApp({super.key, this.bootstrapError});

  /// Se valorizzato, l'app mostra l'errore invece della chat.
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etna Assistant',
      debugShowCheckedModeBanner: false,
      theme: EtnaTheme.light,
      darkTheme: EtnaTheme.dark,
      // Scuro fisso: e' la demo di un talk, proiettata in una sala al buio.
      // Il tema chiaro resta per le @Preview e i golden, non per il palco.
      themeMode: ThemeMode.dark,
      home: bootstrapError != null
          ? _BootstrapErrorPage(message: bootstrapError!)
          : BlocProvider(
              create: (_) => ConversationBloc(EtnaAgent.firebase()),
              child: const ChatPage(),
            ),
    );
  }
}

class _BootstrapErrorPage extends StatelessWidget {
  const _BootstrapErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'La demo non e configurata',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SelectableText(message, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    Text(
                      'Le slide del talk funzionano comunque.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
