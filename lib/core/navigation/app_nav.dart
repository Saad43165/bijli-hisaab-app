import 'package:flutter/material.dart';

/// App-wide navigation the assistant can drive: switch bottom tabs and open
/// screens from outside the widget tree.
class AppNav {
  AppNav._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Bottom tab: 0 Home, 1 History, 2 Appliances, 3 Tools.
  static final tab = ValueNotifier<int>(0);

  static NavigatorState? get _nav => navigatorKey.currentState;

  /// Goes back to the main screen and shows [index].
  static void goTab(int index) {
    _nav?.popUntil((r) => r.isFirst);
    tab.value = index;
  }

  static Future<T?> push<T>(Widget screen) =>
      _nav?.push<T>(MaterialPageRoute<T>(builder: (_) => screen)) ?? Future.value();
}
