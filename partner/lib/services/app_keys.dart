import 'package:flutter/material.dart';

/// Lets services open screens and show banners from outside the widget tree
/// (incoming requests, notification taps, new-message banners).
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Which chat and which request screen are on screen right now, so alerts
/// can be softer (or skipped) for what the lawyer is already looking at.
class OpenScreens {
  static String? chatRequestId;
  static String? incomingRequestId;
}
