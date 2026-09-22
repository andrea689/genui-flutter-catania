import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai/etna_agent.dart';
import 'app/bootstrap.dart';
import 'bloc/conversation_bloc.dart';
import 'catalog/etna_theme.dart';
import 'ui/chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapFirebase();
  runApp(const EtnaAssistantApp());
}

class EtnaAssistantApp extends StatelessWidget {
  const EtnaAssistantApp({super.key});

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
      home: BlocProvider(
        create: (_) => ConversationBloc(EtnaAgent.firebase()),
        child: const ChatPage(),
      ),
    );
  }
}
