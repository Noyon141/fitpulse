import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitPulse',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueAccent),
      // CHANGE: Use StreamBuilder to listen to Auth Changes in real-time
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // While waiting for the stream, check if a user is ALREADY cached.
          // This prevents a "login flicker" when you restart the app.
          if (snapshot.connectionState == ConnectionState.waiting) {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              return const HomeScreen();
            }
          }

          // 2. If the stream has data, check for a valid session
          final session = snapshot.data?.session;

          // 3. Logic: If session exists -> Home. If not -> Login.
          if (session != null) {
            return const HomeScreen();
          } else {
            return const AuthScreen();
          }
        },
      ),
    );
  }
}
