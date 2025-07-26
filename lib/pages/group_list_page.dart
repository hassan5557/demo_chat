import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../models/group_model.dart';
import 'group_chat_page.dart';
import 'create_group_page.dart';
import 'login_page.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  final supabase = Supabase.instance.client;
  late final String myId = supabase.auth.currentUser!.id;
  List<GroupModel> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      // Load groups from local database first
      final localGroups = await LocalDatabaseService.getAllGroups();
      
      if (localGroups.isNotEmpty) {
        setState(() {
          groups = localGroups;
          isLoading = false;
        });
      }

      // Sync with Supabase and update local database
      final res = await supabase
          .from('group_members')
          .select('group_id, groups(id, name, created_at, created_by)')
          .eq('user_id', myId);

      final groupModels = res.map((row) {
        final groupData = row['groups'];
        return GroupModel()
          ..groupId = groupData['id']
          ..name = groupData['name']
          ..createdBy = groupData['created_by']
          ..createdAt = DateTime.parse(groupData['created_at']);
      }).toList();

      await LocalDatabaseService.saveGroups(groupModels);

      setState(() {
        groups = groupModels;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading groups: $e');
      setState(() {
        isLoading = false;
      });
    }
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
                    .then((_) => _loadGroups()); // refresh on return
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                _loadGroups();
              },
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _logout(),
              itemBuilder: (_) => [const PopupMenuItem(value: 'logout', child: Text('Log out'))],
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : groups.isEmpty
                ? const Center(child: Text('No groups'))
                : ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(group.name[0].toUpperCase()),
                        ),
                        title: Text(group.name),
                        subtitle: Text('Created: ${group.createdAt.toString().split(' ')[0]}'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupChatPage(groupId: group.groupId, groupName: group.name),
                          ),
                        ),
                      );
                    },
                  ),
      );
}
