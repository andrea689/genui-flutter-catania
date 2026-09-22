import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ai/etna_agent.dart';
import 'app/bootstrap.dart';
import 'bloc/conversation_bloc.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD1495B)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD1495B),
          brightness: Brightness.dark,
        ),
      ),
      home: BlocProvider(
        create: (_) => ConversationBloc(EtnaAgent.firebase()),
        child: const ChatPage(),
      ),
    );
  }
}
