import 'package:uuid/uuid.dart';

import 'package:blood_pressed/core/db/app_database.dart';
import 'package:blood_pressed/features/llm/domain/llm_models.dart';

/// 健康指导会话的本地持久化（单会话，可清空）。
class ChatRepository {
  ChatRepository(this._db);

  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  Future<List<ChatMessage>> history({int limit = 200}) async {
    final rows = await _db.db.query(
      'chat_messages',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<ChatMessage> append(ChatRole role, String content) async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
    await _db.db.insert('chat_messages', msg.toMap());
    return msg;
  }

  Future<void> updateContent(String id, String content) async {
    await _db.db.update(
      'chat_messages',
      {'content': content},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    await _db.db.delete('chat_messages');
  }
}
