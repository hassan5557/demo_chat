import 'package:isar/isar.dart';
import 'isar_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

class LocalDatabaseService {
  // Message operations
  static Future<void> saveMessage(MessageModel msg) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels.put(msg);
    });
  }

  static Future<List<MessageModel>> getMessagesByChatId(String chatId) async {
    return await IsarService.isar.messageModels
        .filter()
        .chatIdEqualTo(chatId)
        .and()
        .groupIdIsNull()
        .sortByCreatedAt()
        .findAll();
  }

  static Future<List<MessageModel>> getGroupMessages(String groupId) async {
    return await IsarService.isar.messageModels
        .filter()
        .groupIdEqualTo(groupId)
        .sortByCreatedAt()
        .findAll();
  }

  static Future<bool> messageExistsBySupabaseId(String supabaseId) async {
    final existing = await IsarService.isar.messageModels
        .filter()
        .supabaseIdEqualTo(supabaseId)
        .findAll();
    return existing.isNotEmpty;
  }

  static Future<void> deleteChatMessages(String chatId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels
          .filter()
          .chatIdEqualTo(chatId)
          .deleteAll();
    });
  }

  static Future<void> deleteGroupMessages(String groupId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels
          .filter()
          .groupIdEqualTo(groupId)
          .deleteAll();
    });
  }

  // User operations
  static Future<void> saveUser(UserModel user) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.userModels.put(user);
    });
  }

  static Future<void> saveUsers(List<UserModel> users) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.userModels.putAll(users);
    });
  }

  static Future<List<UserModel>> getAllUsers() async {
    return await IsarService.isar.userModels
        .where()
        .sortByEmail()
        .findAll();
  }

  static Future<UserModel?> getUserById(String userId) async {
    final users = await IsarService.isar.userModels
        .filter()
        .userIdEqualTo(userId)
        .findAll();
    return users.isNotEmpty ? users.first : null;
  }

  static Future<void> deleteUser(String userId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.userModels
          .filter()
          .userIdEqualTo(userId)
          .deleteAll();
    });
  }

  // Group operations
  static Future<void> saveGroup(GroupModel group) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupModels.put(group);
    });
  }

  static Future<void> saveGroups(List<GroupModel> groups) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupModels.putAll(groups);
    });
  }

  static Future<List<GroupModel>> getAllGroups() async {
    return await IsarService.isar.groupModels
        .where()
        .sortByCreatedAt()
        .findAll();
  }

  static Future<GroupModel?> getGroupById(String groupId) async {
    final groups = await IsarService.isar.groupModels
        .filter()
        .groupIdEqualTo(groupId)
        .findAll();
    return groups.isNotEmpty ? groups.first : null;
  }

  static Future<void> deleteGroup(String groupId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupModels
          .filter()
          .groupIdEqualTo(groupId)
          .deleteAll();
    });
  }

  // Group member operations
  static Future<void> saveGroupMember(GroupMemberModel member) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupMemberModels.put(member);
    });
  }

  static Future<void> saveGroupMembers(List<GroupMemberModel> members) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupMemberModels.putAll(members);
    });
  }

  static Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    return await IsarService.isar.groupMemberModels
        .filter()
        .groupIdEqualTo(groupId)
        .sortByJoinedAt()
        .findAll();
  }

  static Future<List<GroupMemberModel>> getUserGroups(String userId) async {
    return await IsarService.isar.groupMemberModels
        .filter()
        .userIdEqualTo(userId)
        .sortByJoinedAt()
        .findAll();
  }

  static Future<void> deleteGroupMember(String groupId, String userId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupMemberModels
          .filter()
          .groupIdEqualTo(groupId)
          .and()
          .userIdEqualTo(userId)
          .deleteAll();
    });
  }

  static Future<void> deleteAllGroupMembers(String groupId) async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.groupMemberModels
          .filter()
          .groupIdEqualTo(groupId)
          .deleteAll();
    });
  }

  // Utility operations
  static Future<void> clearAllData() async {
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.messageModels.clear();
      await IsarService.isar.userModels.clear();
      await IsarService.isar.groupModels.clear();
      await IsarService.isar.groupMemberModels.clear();
    });
  }

  static Future<Map<String, int>> getDatabaseStats() async {
    final messageCount = await IsarService.isar.messageModels.count();
    final userCount = await IsarService.isar.userModels.count();
    final groupCount = await IsarService.isar.groupModels.count();
    final memberCount = await IsarService.isar.groupMemberModels.count();

    return {
      'messages': messageCount,
      'users': userCount,
      'groups': groupCount,
      'members': memberCount,
    };
  }
} 