import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kpexslwrsstfkelyowbq.supabase.co',
    anonKey: 'sb_publishable_ZA7A8pzOf_BWwNdSKLEE6A_USDNtP0_',
  );

  runApp(const EventHubApp());
}

// Handy shortcut to access Supabase anywhere in the app
final supabase = Supabase.instance.client;

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ConnectionTestScreen(),
    );
  }
}

// Temporary screen just to prove Supabase is connected.
// We'll replace this with the real Login screen next.
class ConnectionTestScreen extends StatelessWidget {
  const ConnectionTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EventHub')),
      body: const Center(
        child: Text(
          'Supabase connected ✅',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}