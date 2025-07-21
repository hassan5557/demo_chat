import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final supabase = Supabase.instance.client;
  final _groupNameController = TextEditingController();
  List<Map<String, dynamic>> allUsers = [];
  List<String> selectedUserIds = [];

  late final String myId = supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final res = await supabase.from('users').select('id, email').neq('id', myId);
    setState(() {
      allUsers = List<Map<String, dynamic>>.from(res);
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter group name and select members')));
      return;
    }

    try {
      final groupRes = await supabase.from('groups').insert({'name': name}).select().single();
      final groupId = groupRes['id'] as String;

      // Add current user as member too
      final members = [myId, ...selectedUserIds];

      // Insert group members
      await supabase.from('group_members').insert(
        members.map((uid) => {'group_id': groupId, 'user_id': uid}).toList(),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Group')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              const SizedBox(height: 20),
              const Text('Select Members'),
              Expanded(
                child: ListView.builder(
                  itemCount: allUsers.length,
                  itemBuilder: (context, index) {
                    final user = allUsers[index];
                    final isSelected = selectedUserIds.contains(user['id']);
                    return CheckboxListTile(
                      title: Text(user['email']),
                      value: isSelected,
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            selectedUserIds.add(user['id']);
                          } else {
                            selectedUserIds.remove(user['id']);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              ElevatedButton(onPressed: _createGroup, child: const Text('Create Group')),
            ],
          ),
        ),
      );
}
