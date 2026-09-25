import 'package:flutter/material.dart';

/// Lets a screen react when it becomes visible again after a route above
/// it is popped (e.g. so it can re-read state that changed while covered).
final routeObserver = RouteObserver<ModalRoute<void>>();
