import 'package:isar/isar.dart';

part 'user_model.g.dart';

@Collection()
class UserModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String userId; // Supabase user ID
  
  late String email;
  String? name;
  DateTime? lastSeen;
  late DateTime createdAt;
} 