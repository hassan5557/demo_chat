import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String makeChatId(String id1, String id2) {
  final sorted = [id1, id2]..sort();
  return '${sorted[0]}_${sorted[1]}';
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
    final res = await supabase.from('messages').select().eq('chat_id', chatId).order('created_at');
    messages = List<Map<String, dynamic>>.from(res);
    _chatCache[chatId] = List<Map<String, dynamic>>.from(messages);
    setState(() {});
    _scrollToBottom();
  }

  void _subscribeToMessages() {
    _subscription = supabase.from('messages').stream(primaryKey: ['id']).eq('chat_id', chatId).order('created_at').listen((newMessages) {
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
    _subscription?.cancel();
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
                        color: isMe ? Colors.blue.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['content'],
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
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

