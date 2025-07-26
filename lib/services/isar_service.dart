import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';

class IsarService {
  static late Isar isar;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([
      MessageModelSchema,
      UserModelSchema,
      GroupModelSchema,
      GroupMemberModelSchema,
    ], directory: dir.path);
  }
}
