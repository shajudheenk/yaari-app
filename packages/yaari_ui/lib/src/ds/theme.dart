import 'package:flutter/material.dart';

import 'tokens.dart';

/// The Flutter theme, derived from the tokens.
///
/// Every default Material surface is overridden here rather than at the call
/// site, so a widget nobody has styled yet still lands inside the design
/// system instead of showing Material's purple.
ThemeData buildYaariTheme({Color accent = Brand.c500}) {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Surface.canvas,
    fontFamily: Face.text,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      primary: accent,
      surface: Surface.raised,
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: Txt.hero,
      displaySmall: Txt.display,
      headlineMedium: Txt.display,
      titleLarge: Txt.title,
      titleMedium: Txt.section,
      bodyLarge: Txt.body,
      bodyMedium: Txt.body,
      bodySmall: Txt.bodySm,
      labelSmall: Txt.label,
      labelMedium: Txt.meta,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Coal.c900),
      titleTextStyle: Txt.section,
    ),
    dividerTheme: const DividerThemeData(
        color: Coal.c100, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // Presses are answered by the spring in Pressable. Material's ripple on
    // top of that reads as two different design languages arguing.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Surface.raised,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
      hintStyle: Txt.bodySm,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        borderSide: const BorderSide(color: Coal.c200, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        borderSide: const BorderSide(color: Coal.c200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.button),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Coal.c900,
      contentTextStyle: Txt.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button)),
    ),
  );
}

/// Page transitions.
///
/// The incoming screen rises and fades while the one beneath sinks slightly
/// away — the two read as one surface moving rather than two pages being
/// swapped, which is what the stock platform slide always looks like.
class YaariPage<T> extends PageRouteBuilder<T> {
  YaariPage({required this.builder, super.settings})
      : super(
          transitionDuration: Motion.page,
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, a, b) => builder(context),
          transitionsBuilder: (context, a, b, child) {
            if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
              return child;
            }
            final curved =
                CurvedAnimation(parent: a, curve: Motion.enter, reverseCurve: Motion.exit);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 0.97).animate(
                      CurvedAnimation(parent: b, curve: Motion.settle)),
                  child: child,
                ),
              ),
            );
          },
        );

  final WidgetBuilder builder;
}

extension YaariNavX on NavigatorState {
  Future<T?> go<T>(WidgetBuilder builder) =>
      push<T>(YaariPage<T>(builder: builder));
}
