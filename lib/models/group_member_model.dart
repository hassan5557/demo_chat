import 'package:isar/isar.dart';

part 'group_member_model.g.dart';

@Collection()
class GroupMemberModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String groupId;
  
  @Index()
  late String userId;
  
  late DateTime joinedAt;
  String? role; // admin, member, etc.
} 