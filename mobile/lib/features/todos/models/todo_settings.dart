import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TodoCompletionStyle {
  checkmark,
  strikethrough,
}

const _todoCompletionStyleKey = 'todo_completion_style';

final todoCompletionStyleProvider =
    StateNotifierProvider<TodoSettingsNotifier, TodoCompletionStyle>((ref) {
  return TodoSettingsNotifier()..load();
});

class TodoSettingsNotifier extends StateNotifier<TodoCompletionStyle> {
  TodoSettingsNotifier() : super(TodoCompletionStyle.checkmark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_todoCompletionStyleKey);

    if (value == 'strikethrough') {
      state = TodoCompletionStyle.strikethrough;
    } else {
      state = TodoCompletionStyle.checkmark;
    }
  }

  Future<void> setStyle(TodoCompletionStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todoCompletionStyleKey, style.name);
  }
}