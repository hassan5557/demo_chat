import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../models/message_model.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatPage({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final supabase = Supabase.instance.client;
  final _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<MessageModel> messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  late final String myId = supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    try {
      // Load messages from local Isar DB first
      final localMessages = await LocalDatabaseService.getGroupMessages(widget.groupId);

      if (localMessages.isNotEmpty) {
        setState(() => messages = localMessages);
        _scrollToBottom();
      }

      // Sync with Supabase messages from remote and save to Isar
      final res = await supabase
          .from('group_messages')
          .select('id, content, sender_id, group_id, created_at, users!fk_sender_user(email)')
          .eq('group_id', widget.groupId)
          .order('created_at');

      for (var row in res) {
        final supabaseId = row['id'].toString();
        final exists = await LocalDatabaseService.messageExistsBySupabaseId(supabaseId);
        
        if (!exists) {
          final msg = MessageModel()
            ..chatId = widget.groupId // Use groupId as chatId for consistency
            ..groupId = row['group_id']
            ..content = row['content']
            ..senderId = row['sender_id']
            ..senderEmail = row['users']?['email']
            ..supabaseId = supabaseId
            ..createdAt = DateTime.parse(row['created_at']);

          await LocalDatabaseService.saveMessage(msg);
        }
      }

      final updatedMessages = await LocalDatabaseService.getGroupMessages(widget.groupId);
      setState(() {
        messages = updatedMessages;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading group messages: $e');
    }
  }

  void _subscribeToMessages() {
    _subscription = supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', widget.groupId)
        .order('created_at')
        .listen((newMessages) async {
      try {
        bool updated = false;

        for (var row in newMessages) {
          final supabaseId = row['id'].toString();
          
          // Check if message already exists in local database
          final exists = await LocalDatabaseService.messageExistsBySupabaseId(supabaseId);
          
          if (!exists) {
            final msg = MessageModel()
              ..chatId = widget.groupId
              ..groupId = row['group_id']
              ..content = row['content']
              ..senderId = row['sender_id']
              ..senderEmail = row['users']?['email']
              ..supabaseId = supabaseId
              ..createdAt = DateTime.parse(row['created_at']);
            await LocalDatabaseService.saveMessage(msg);
            updated = true;
          }
        }

        if (updated) {
          final refreshed = await LocalDatabaseService.getGroupMessages(widget.groupId);
          setState(() => messages = refreshed);
          _scrollToBottom();
        }
      } catch (e) {
        print('Error in group message subscription: $e');
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    // Send to Supabase first to get the ID
    try {
      final response = await supabase.from('group_messages').insert({
        'group_id': widget.groupId,
        'content': text,
        'sender_id': myId,
      }).select();

      if (response.isNotEmpty) {
        final supabaseMsg = response.first;
        
        final newMsg = MessageModel()
          ..chatId = widget.groupId
          ..groupId = widget.groupId
          ..content = text
          ..senderId = myId
          ..supabaseId = supabaseMsg['id'].toString()
          ..createdAt = DateTime.now();

        // Add locally with the correct supabaseId
        setState(() {
          messages.add(newMsg);
        });
        _scrollToBottom();

        await LocalDatabaseService.saveMessage(newMsg);
      }
    } catch (e) {
      print('Send group message failed: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.groupName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New group name'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != widget.groupName) {
                Navigator.pop(context);
                await _renameGroup(newName);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _renameGroup(String newName) async {
    try {
      await supabase.from('groups').update({'name': newName}).eq('id', widget.groupId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(groupId: widget.groupId, groupName: newName),
        ),
      );
    } catch (e) {
      print('Rename failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to rename group')),
      );
    }
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
        appBar: AppBar(
          title: Text(widget.groupName),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Rename Group',
              onPressed: _showRenameDialog,
            ),
          ],
        ),
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
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      constraints:
                          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                msg.senderEmail ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          Text(
                            msg.content,
                            style: TextStyle(
                              fontSize: 16,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
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
                      decoration: const InputDecoration(
                        labelText: 'Type a message',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessage,
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}


