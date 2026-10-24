/// A button under an assistant reply ("View full bill", "Open History").
class ReplyAction {
  const ReplyAction(this.label, this.run);

  final String label;

  /// Runs the action; may return a follow-up message to show.
  final Future<String?> Function() run;
}

/// Where a reply came from, shown as a small label under it.
enum ReplySource {
  /// App messages (welcome, "Stopped."): no label.
  app,

  /// Worked out on the phone from the user's own data.
  data,

  /// Written by the AI (checked against the app's numbers first).
  ai,
}

class ChatMessage {
  ChatMessage({
    required this.fromUser,
    required this.text,
    this.imagePath,
    this.actions = const [],
    this.source = ReplySource.app,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  final bool fromUser;
  final DateTime time;
  final String text;

  /// A bill photo the user attached.
  final String? imagePath;
  final List<ReplyAction> actions;
  final ReplySource source;
}

class AssistantReply {
  const AssistantReply(
    this.text, {
    this.actions = const [],
    this.understood = true,
    this.canImprove = false,
    this.source = ReplySource.data,
  });

  final String text;
  final List<ReplyAction> actions;
  final ReplySource source;

  /// false when the built-in brain didn't understand (the AI should try).
  final bool understood;

  /// A generic answer (FAQ, greeting): the AI may give a better one.
  final bool canImprove;
}

/// Something that answers the user: the built-in brain or the cloud AI.
abstract class AssistantBrain {
  Future<AssistantReply> respond(String text, {String? imagePath, List<ChatMessage> history = const []});
}
