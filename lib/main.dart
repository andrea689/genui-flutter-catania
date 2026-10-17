import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'catalog/etna_theme.dart';
import 'ui/etna_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If bootstrap fails, the site is still linked from the talk: a screen that
  // explains the problem beats a blank page with a 403 hidden in DevTools.
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

  /// If set, the app shows the error instead of the chat.
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Etna Assistant',
      debugShowCheckedModeBanner: false,
      theme: EtnaTheme.light,
      darkTheme: EtnaTheme.dark,
      // Always dark: it's a talk demo, projected in a dark room.
      // The light theme is kept for the @Previews and goldens, not the stage.
      themeMode: ThemeMode.dark,
      home: bootstrapError != null
          ? _BootstrapErrorPage(message: bootstrapError!)
          : const EtnaHome(),
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
                            'La demo non è configurata',
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
