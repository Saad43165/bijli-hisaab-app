/// A button under an assistant reply ("View full bill", "Open History").
class ReplyAction {
  const ReplyAction(this.label, this.run);

  final String label;

  /// Runs the action; may return a follow-up message to show.
  final Future<String?> Function() run;
}

class ChatMessage {
  ChatMessage({required this.fromUser, required this.text, this.imagePath, this.actions = const [], DateTime? time})
      : time = time ?? DateTime.now();

  final bool fromUser;
  final DateTime time;
  final String text;

  /// A bill photo the user attached.
  final String? imagePath;
  final List<ReplyAction> actions;
}

class AssistantReply {
  const AssistantReply(this.text, {this.actions = const [], this.understood = true, this.canImprove = false});

  final String text;
  final List<ReplyAction> actions;

  /// false when the built-in brain didn't understand (the AI should try).
  final bool understood;

  /// A generic answer (FAQ, greeting): the AI may give a better one.
  final bool canImprove;
}

/// Something that answers the user: the built-in brain or the cloud AI.
abstract class AssistantBrain {
  Future<AssistantReply> respond(String text, {String? imagePath, List<ChatMessage> history = const []});
}
