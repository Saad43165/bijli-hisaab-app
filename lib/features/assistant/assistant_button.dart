import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import 'assistant_avatar.dart';
import 'assistant_screen.dart';

/// The assistant's button for app bars: the app's own logo with a spark.
class AssistantButton extends StatelessWidget {
  const AssistantButton({super.key, this.ask});

  /// Optional question to start the chat with.
  final String? ask;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: 'Ask the assistant'.tr,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => AssistantScreen(initialMessage: ask))),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: AssistantAvatar(size: 38),
          ),
        ),
      ),
    );
  }
}
