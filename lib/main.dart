import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/isar_service.dart';

import 'pages/login_page.dart';
import 'pages/user_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://tdjozqmzphhyyygxizyo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkam96cW16cGhoeXl5Z3hpenlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNjY2MjksImV4cCI6MjA2NzY0MjYyOX0.6ZRhPggU75ByEiDei-TJCU3G49--m_plPwJBvDQCmuM',
  );

  // Initialize Isar
  await IsarService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? const LoginPage() : const UserListPage();
  }
}

