import 'package:isar/isar.dart';

import 'isar_service.dart';
import '../models/message_model.dart';

// This service is kept for backward compatibility
// For new features, use LocalDatabaseService instead

class LocalDbService {
  /// Save a message to local Isar DB
  static Future<void> saveMessage(MessageModel msg) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels.put(msg);
    });
  }

  /// Get all messages for a specific chat (individual)
  static Future<List<MessageModel>> getMessagesByChatId(String chatId) async {
    return await IsarService.isar.messageModels
        .filter()
        .chatIdEqualTo(chatId)
        .and()
        .groupIdIsNull()
        .sortByCreatedAt()
        .findAll();
  }

  /// Get all messages for a specific group
  static Future<List<MessageModel>> getGroupMessages(String groupId) async {
    return await IsarService.isar.messageModels
        .filter()
        .groupIdEqualTo(groupId)
        .sortByCreatedAt()
        .findAll();
  }

  /// Get all messages for a specific group using chatId
  static Future<List<MessageModel>> getGroupMessagesByChatId(String chatId) async {
    return await IsarService.isar.messageModels
        .filter()
        .chatIdEqualTo(chatId)
        .and()
        .groupIdIsNotNull()
        .sortByCreatedAt()
        .findAll();
  }

  /// Delete all messages for a specific chat
  static Future<void> deleteChatMessages(String chatId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels
          .filter()
          .chatIdEqualTo(chatId)
          .deleteAll();
    });
  }

  /// Delete all messages for a specific group
  static Future<void> deleteGroupMessages(String groupId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels
          .filter()
          .groupIdEqualTo(groupId)
          .deleteAll();
    });
  }

  /// Get all messages
  static Future<List<MessageModel>> getAllMessages() async {
    return await IsarService.isar.messageModels
        .where()
        .sortByCreatedAt()
        .findAll();
  }

  /// Check if a message already exists
  static Future<bool> messageExists(String content, String senderId, DateTime createdAt) async {
    final existing = await IsarService.isar.messageModels
        .filter()
        .contentEqualTo(content)
        .and()
        .senderIdEqualTo(senderId)
        .and()
        .createdAtEqualTo(createdAt)
        .findAll();
    return existing.isNotEmpty;
  }

  /// Check if a message exists by Supabase ID
  static Future<bool> messageExistsBySupabaseId(String supabaseId) async {
    final existing = await IsarService.isar.messageModels
        .filter()
        .supabaseIdEqualTo(supabaseId)
        .findAll();
    return existing.isNotEmpty;
  }

  /// Clear all messages (useful for testing or reset)
  static Future<void> clearAllMessages() async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels.clear();
    });
  }

  /// Get message count for debugging
  static Future<int> getMessageCount() async {
    return await IsarService.isar.messageModels.count();
  }

  /// Get message count for a specific chat
  static Future<int> getChatMessageCount(String chatId) async {
    return await IsarService.isar.messageModels
        .filter()
        .chatIdEqualTo(chatId)
        .count();
  }

  /// Get message count for a specific group
  static Future<int> getGroupMessageCount(String groupId) async {
    return await IsarService.isar.messageModels
        .filter()
        .groupIdEqualTo(groupId)
        .count();
  }

  /// Get all unique chat IDs (for individual chats)
  static Future<List<String>> getAllChatIds() async {
    final messages = await IsarService.isar.messageModels
        .filter()
        .groupIdIsNull()
        .findAll();
    return messages.map((m) => m.chatId).toSet().toList();
  }

  /// Get all unique group IDs
  static Future<List<String>> getAllGroupIds() async {
    final messages = await IsarService.isar.messageModels
        .filter()
        .groupIdIsNotNull()
        .findAll();
    return messages.map((m) => m.groupId!).toSet().toList();
  }
}
