import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUsers() async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('users')
        .select()
        .neq('id', userId);

    return List<Map<String, dynamic>>.from(response);
  }

  void _signOut() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text("All Users"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            )
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: getUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = snapshot.data!;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, i) {
                final user = users[i];
                return ListTile(
                  title: Text(user['email'] ?? 'No email'),
                );
              },
            );
          },
        ),
      );
}
