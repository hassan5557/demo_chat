import 'package:chat_demo/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';
import 'group_list_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final supabase = Supabase.instance.client;
  late final String myId = supabase.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> _getUsers() async {
    final res = await supabase.from('users').select('id, email').neq('id', myId);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Select User'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Group Chats',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupListPage()));
              },
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _logout(),
              itemBuilder: (_) => [const PopupMenuItem(value: 'logout', child: Text('Log out'))],
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _getUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!;
            if (users.isEmpty) return const Center(child: Text('No users'));
            return ListView(
              children: users
                  .map(
                    (user) => ListTile(
                      title: Text(user['email']),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(peerId: user['id'], peerEmail: user['email']),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      );
}
