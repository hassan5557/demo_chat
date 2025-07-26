import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../models/message_model.dart';

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

  List<MessageModel> messages = [];

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    try {
          // Load messages from local Isar DB first
    final localMessages = await LocalDatabaseService.getMessagesByChatId(chatId);

      if (localMessages.isNotEmpty) {
        setState(() => messages = localMessages);
        _scrollToBottom();
      }

      // Sync with Supabase messages from remote and save to Isar
      final res = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at');

      for (final row in res) {
        final supabaseId = row['id'].toString();
        final exists = await LocalDatabaseService.messageExistsBySupabaseId(supabaseId);
        if (!exists) {
          final msg = MessageModel()
            ..chatId = row['chat_id']
            ..content = row['content']
            ..senderId = row['sender_id']
            ..receiverId = row['receiver_id']
            ..supabaseId = supabaseId
            ..createdAt = DateTime.parse(row['created_at']);
          await LocalDatabaseService.saveMessage(msg);
        }
      }

      final updatedMessages = await LocalDatabaseService.getMessagesByChatId(chatId);
      setState(() {
        messages = updatedMessages;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      // Show error message to user if needed
    }
  }

  void _subscribeToMessages() {
    _subscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .listen((newMessages) async {
      try {
        bool updated = false;
        for (var msg in newMessages) {
          final createdAt = DateTime.parse(msg['created_at']);
          final supabaseId = msg['id'].toString();
          
          // Check if message already exists in local database
          final exists = await LocalDatabaseService.messageExistsBySupabaseId(supabaseId);
          
          if (!exists) {
            final newMsg = MessageModel()
              ..chatId = msg['chat_id']
              ..content = msg['content']
              ..senderId = msg['sender_id']
              ..receiverId = msg['receiver_id']
              ..supabaseId = supabaseId
              ..createdAt = createdAt;
            await LocalDatabaseService.saveMessage(newMsg);
            messages.add(newMsg);
            updated = true;
          }
        }
        if (updated) {
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          setState(() {});
          _scrollToBottom();
        }
      } catch (e) {
        print('Error in message subscription: $e');
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();

    final now = DateTime.now();

    // Send to Supabase first to get the ID
    try {
      final response = await supabase.from('messages').insert({
        'chat_id': chatId,
        'content': text,
        'sender_id': myId,
        'receiver_id': widget.peerId,
      }).select();

      if (response.isNotEmpty) {
        final supabaseMsg = response.first;
        
        final newMsg = MessageModel()
          ..chatId = chatId
          ..content = text
          ..senderId = myId
          ..receiverId = widget.peerId
          ..createdAt = now
          ..supabaseId = supabaseMsg['id'].toString();

        // Add locally with the correct supabaseId
        setState(() {
          messages.add(newMsg);
        });
        _scrollToBottom();

        await LocalDatabaseService.saveMessage(newMsg);
      }
    } catch (e) {
      print('Send message failed: $e');
      // Optionally: mark message as failed in local DB or retry later
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
                  final isMe = msg.senderId == myId;
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
                        msg.content,
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

