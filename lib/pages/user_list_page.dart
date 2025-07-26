import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../models/user_model.dart';
import 'chat_page.dart';
import 'group_list_page.dart';
import 'login_page.dart';
import 'debug_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final supabase = Supabase.instance.client;
  late final String myId = supabase.auth.currentUser!.id;
  List<UserModel> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _testSupabaseConnection() async {
    try {
      print('Testing Supabase connection...');
      
      // Test 1: Check if we can connect to Supabase
      final testRes = await supabase.from('users').select('count').limit(1);
      print('Connection test result: $testRes');
      
      // Test 2: Get all users without any filters
      final allUsers = await supabase.from('users').select('*');
      print('All users from Supabase: $allUsers');
      print('Total users found: ${allUsers.length}');
      
      // Test 3: Check current user
      final currentUser = supabase.auth.currentUser;
      print('Current user: ${currentUser?.email}');
      print('Current user ID: ${currentUser?.id}');
      
    } catch (e) {
      print('Supabase connection test failed: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      // Load users from local database first
      final localUsers = await LocalDatabaseService.getAllUsers();
      
      if (localUsers.isNotEmpty) {
        setState(() {
          users = localUsers.where((user) => user.userId != myId).toList();
          isLoading = false;
        });
      }

      // Sync with Supabase and update local database
      final res = await supabase.from('users').select('id, email');
      
      print('Supabase response: $res'); // Debug print
      
      final userModels = res.map((user) {
        final userModel = UserModel()
          ..userId = user['id']
          ..email = user['email']
          ..createdAt = DateTime.now(); // Use current time since created_at doesn't exist
        
        return userModel;
      }).toList();

      print('Found ${userModels.length} users'); // Debug print
      print('Current user ID: $myId'); // Debug print

      await LocalDatabaseService.saveUsers(userModels);

      setState(() {
        users = userModels.where((user) => user.userId != myId).toList();
        isLoading = false;
      });
      
      print('Filtered users count: ${users.length}'); // Debug print
    } catch (e) {
      print('Error loading users: $e');
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
          title: const Text('Select User'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Group Chats',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupListPage()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                _loadUsers();
              },
            ),
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug Database',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugPage()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: 'Test Connection',
              onPressed: () {
                _testSupabaseConnection();
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
            : users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No other users found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are the only registered user',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                            });
                            _loadUsers();
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.email[0].toUpperCase()),
                        ),
                        title: Text(user.email),
                        subtitle: Text('User ID: ${user.userId}'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(peerId: user.userId, peerEmail: user.email),
                          ),
                        ),
                      );
                    },
                  ),
      );
}
