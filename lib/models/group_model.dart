import 'package:isar/isar.dart';

part 'group_model.g.dart';

@Collection()
class GroupModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String groupId; // Supabase group ID
  
  late String name;
  String? description;
  late String createdBy;
  late DateTime createdAt;
  DateTime? updatedAt;
} 