import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//kk555
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://tdjozqmzphhyyygxizyo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkam96cW16cGhoeXl5Z3hpenlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNjY2MjksImV4cCI6MjA2NzY0MjYyOX0.6ZRhPggU75ByEiDei-TJCU3G49--m_plPwJBvDQCmuM',
  );
  runApp(const MyApp());
}

String makeChatId(String id1, String id2) {
  final sorted = [id1, id2]..sort();
  return '${sorted[0]}_${sorted[1]}';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Supabase Chat',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const LoginPage(),
      );
}

// LOGIN PAGE
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> _login() async {
    try {
      final res = await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      if (res.user != null) {
        await supabase.from('users').upsert({
          'id': res.user!.id,
          'email': res.user!.email,
        });
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserListPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _login, child: const Text('Login')),
            ],
          ),
        ),
      );
}

// USER LIST PAGE
class UserListPage extends StatefulWidget {
  const UserListPage({super.key});
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final supabase = Supabase.instance.client;
  late final String myId = supabase.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> _getUsers() async {
    final res =
        await supabase.from('users').select('id, email').neq('id', myId);
    return List<Map<String, dynamic>>.from(res);
  }

  /* ── NEW: simple logout ── */
  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Select User'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (_) => _logout(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'logout', child: Text('Log out')),
              ],
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
                          builder: (_) => ChatPage(
                            peerId: user['id'],
                            peerEmail: user['email'],
                          ),
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


class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerEmail;
  const ChatPage({super.key, required this.peerId, required this.peerEmail});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final supabase = Supabase.instance.client;
  final _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final String myId = supabase.auth.currentUser!.id;
  late final String chatId = makeChatId(myId, widget.peerId);

  static final Map<String, List<Map<String, dynamic>>> _chatCache = {};
  List<Map<String, dynamic>> messages = [];

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();

    if (_chatCache.containsKey(chatId)) {
      messages = List<Map<String, dynamic>>.from(_chatCache[chatId]!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      _loadMessages();
    }

    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    final res = await supabase
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at');
    messages = List<Map<String, dynamic>>.from(res);
    _chatCache[chatId] = List<Map<String, dynamic>>.from(messages);
    setState(() {});
    _scrollToBottom();
  }

  void _subscribeToMessages() {
    _subscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .listen((newMessages) {
      bool updated = false;
      for (var msg in newMessages) {
        if (!messages.any((m) => m['id'] == msg['id'])) {
          messages.add(msg);
          updated = true;
        }
      }
      if (updated) {
        messages.sort((a, b) => a['created_at'].compareTo(b['created_at']));
        _chatCache[chatId] = List<Map<String, dynamic>>.from(messages);
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    try {
      await supabase.from('messages').insert({
        'chat_id': chatId,
        'content': text,
        'sender_id': myId,
        'receiver_id': widget.peerId,
      });
    } catch (e) {
      print('Send message failed: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _subscription?.cancel(); // ✅ Cancel stream to prevent ghost listeners
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Chat with ${widget.peerEmail}')),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg['sender_id'] == myId;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[200] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg['content']),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(labelText: 'Type a message'),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
                ],
              ),
            ),
          ],
        ),
      );
}
