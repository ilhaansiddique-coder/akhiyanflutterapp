import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:akhiyan_admin/app.dart';
import 'package:akhiyan_admin/src/core/widgets/friendly_error_widget.dart';

void main() {
  // Replace Flutter's red ErrorWidget with a friendly card so a build-time
  // exception in one widget never paints a wall of stack frames at the user.
  ErrorWidget.builder = (details) => FriendlyErrorWidget(details: details);

  // Catch widget/framework errors. In debug we keep the default presentation
  // (so the IDE devtools still surface them); in release we just log so
  // crash reporting can pick them up later without spamming the console.
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      debugPrint('[flutter error] ${details.exceptionAsString()}');
    }
  };

  // Catch errors from outside the widget tree (async gaps, platform channels,
  // isolates). Returning true marks them handled so they don't crash the app.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[platform error] $error');
    return true;
  };

  // runZonedGuarded catches anything the two handlers above miss — e.g. a
  // sync throw inside a Future without a .catchError.
  runZonedGuarded(
    () => runApp(const ProviderScope(child: AkhiyanAdminApp())),
    (error, stack) {
      debugPrint('[zone error] $error');
    },
  );
}
