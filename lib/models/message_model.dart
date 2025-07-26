import 'package:isar/isar.dart';

part 'message_model.g.dart'; // Generated file

@Collection()
class MessageModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String chatId;
  
  @Index()
  String? groupId; // For group messages
  
  late String content;
  late String senderId;
  String? receiverId; // For individual chats
  String? senderEmail; // For display purposes
  String? supabaseId; // To track Supabase message ID
  late DateTime createdAt;
}

