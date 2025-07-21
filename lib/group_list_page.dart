import 'package:chat_demo/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'group_chat_page.dart';
import 'create_group_page.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  final supabase = Supabase.instance.client;
  late final String myId = supabase.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> _getGroups() async {
    final res = await supabase
        .from('group_members')
        .select('group_id, groups(name)')
        .eq('user_id', myId);
    // flatten and get group info with group_id and name
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
          title: const Text('Group Chats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create Group',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupPage()))
                    .then((_) => setState(() {})); // refresh on return
              },
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _logout(),
              itemBuilder: (_) => [const PopupMenuItem(value: 'logout', child: Text('Log out'))],
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _getGroups(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final groups = snapshot.data!;
            if (groups.isEmpty) return const Center(child: Text('No groups'));

            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final groupId = group['group_id'] as String;
                final groupName = group['groups']['name'] as String;
                return ListTile(
                  title: Text(groupName),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName)),
                  ),
                );
              },
            );
          },
        ),
      );
}
