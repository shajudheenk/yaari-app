import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptics.
///
/// Wrapped rather than called directly so the whole app speaks one vocabulary:
/// a tap is lighter than a commitment, and an error is the only thing allowed
/// to feel heavy. Silent on platforms with no vibrator, which is why every call
/// site can fire and forget.
class Buzz {
  /// Moving between things: a tile, a tab, a chip.
  static void tap() => HapticFeedback.selectionClick();

  /// Something changed state because you did it: selecting a service,
  /// picking a slot, toggling availability.
  static void pick() => HapticFeedback.lightImpact();

  /// A commitment: booking requested, job accepted, work completed.
  static void commit() => HapticFeedback.mediumImpact();

  /// It did not work. Deliberately the only heavy one in the app.
  static void reject() => HapticFeedback.heavyImpact();
}

/// The app's easing.
///
/// Material's default easing is symmetrical and linear-feeling, which is a
/// large part of why a stock Flutter app reads as a stock Flutter app.
/// Everything here decelerates hard: motion arrives fast and settles slowly,
/// the way a physical object does when something heavier than a pixel is
/// moving it.
class YaariCurves {
  /// Things entering the screen. Overshoots very slightly, so an arriving
  /// panel looks like it has weight rather than sliding to a stop on rails.
  static const enter = Cubic(0.16, 1.02, 0.3, 1);

  /// Things leaving. Deliberately quicker and without the overshoot — an exit
  /// that lingers feels like lag, not polish.
  static const exit = Cubic(0.4, 0, 0.9, 0.2);

  /// State changing in place: a row selecting, a chip filling, a price
  /// updating. Short, flat, no bounce.
  static const settle = Cubic(0.2, 0, 0, 1);

  static const enterDuration = Duration(milliseconds: 420);
  static const exitDuration = Duration(milliseconds: 220);
  static const settleDuration = Duration(milliseconds: 180);
}

/// Pushes a screen with a fade-through rather than the platform slide.
///
/// The default Material push slides a whole page in from the right, which
/// reads as "another page of the same list". Content that opens out of a tile
/// should feel like that tile expanding, so the incoming screen fades up and
/// settles rather than arriving from offstage.
class YaariRoute<T> extends PageRouteBuilder<T> {
  YaariRoute({required this.builder, super.settings})
      : super(
          transitionDuration: YaariCurves.enterDuration,
          reverseTransitionDuration: YaariCurves.exitDuration,
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final reduced =
                MediaQuery.maybeDisableAnimationsOf(context) ?? false;
            if (reduced) return child;

            final curved = CurvedAnimation(
              parent: animation,
              curve: YaariCurves.enter,
              reverseCurve: YaariCurves.exit,
            );

            // The incoming screen rises a short distance as it fades up, and
            // the one underneath sinks fractionally away. Together they read
            // as one surface moving rather than two pages being swapped.
            final rise = Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved);

            final under = Tween<double>(begin: 1, end: 0.97).animate(
              CurvedAnimation(parent: secondary, curve: YaariCurves.settle),
            );

            return ScaleTransition(
              scale: under,
              child: FadeTransition(
                opacity: curved,
                child: SlideTransition(position: rise, child: child),
              ),
            );
          },
        );

  final WidgetBuilder builder;
}

/// Convenience so call sites read the same as `Navigator.push`.
extension YaariNav on NavigatorState {
  Future<T?> pushYaari<T>(WidgetBuilder builder) =>
      push<T>(YaariRoute<T>(builder: builder));
}
