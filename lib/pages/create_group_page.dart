import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final supabase = Supabase.instance.client;
  final _groupNameController = TextEditingController();
  List<UserModel> allUsers = [];
  List<String> selectedUserIds = [];
  bool isLoading = true;

  late final String myId = supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      // Load users from local database first
      final localUsers = await LocalDatabaseService.getAllUsers();
      
      if (localUsers.isNotEmpty) {
        setState(() {
          allUsers = localUsers.where((user) => user.userId != myId).toList();
          isLoading = false;
        });
      }

      // Sync with Supabase and update local database
      final res = await supabase.from('users').select('id, email, created_at');
      
      final userModels = res.map((user) => UserModel()
        ..userId = user['id']
        ..email = user['email']
        ..createdAt = DateTime.parse(user['created_at'])).toList();

      await LocalDatabaseService.saveUsers(userModels);

      setState(() {
        allUsers = userModels.where((user) => user.userId != myId).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter group name and select members')));
      return;
    }

    try {
      // Create group in Supabase
      final groupRes = await supabase.from('groups').insert({'name': name}).select().single();
      final groupId = groupRes['id'] as String;

      // Add current user as member too
      final members = [myId, ...selectedUserIds];

      // Insert group members in Supabase
      await supabase.from('group_members').insert(
        members.map((uid) => {'group_id': groupId, 'user_id': uid}).toList(),
      );

      // Save group to local database
      final groupModel = GroupModel()
        ..groupId = groupId
        ..name = name
        ..createdBy = myId
        ..createdAt = DateTime.now();

      await LocalDatabaseService.saveGroup(groupModel);

      // Save group members to local database
      final memberModels = members.map((userId) => GroupMemberModel()
        ..groupId = groupId
        ..userId = userId
        ..joinedAt = DateTime.now()
        ..role = userId == myId ? 'admin' : 'member').toList();

      await LocalDatabaseService.saveGroupMembers(memberModels);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Group')),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
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
                          final isSelected = selectedUserIds.contains(user.userId);
                          return CheckboxListTile(
                            title: Text(user.email),
                            subtitle: Text('User ID: ${user.userId}'),
                            value: isSelected,
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedUserIds.add(user.userId);
                                } else {
                                  selectedUserIds.remove(user.userId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _createGroup,
                      child: const Text('Create Group'),
                    ),
                  ],
                ),
              ),
      );
}
