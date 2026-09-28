import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components.dart';
import 'tokens.dart';

/// Press and hold to commit.
///
/// Used where a tap would be too easy to do by accident and a confirmation
/// dialog would be too slow — starting a job, closing a job. The ring fills
/// while the finger is down and the action only fires when it completes, so
/// a pocket press or a misjudged tap costs nothing.
///
/// Haptics mark the two moments that matter: a light tick when the hold
/// begins, a firmer one when it commits.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = Icons.play_arrow_rounded,
    this.colour,
    this.hint,
    this.busy = false,
    this.duration = const Duration(milliseconds: 1000),
  });

  final String label;
  final VoidCallback? onConfirmed;
  final IconData icon;
  final Color? colour;

  /// Shown under the control — "Hold to start", or why it is disabled.
  final String? hint;

  final bool busy;
  final Duration duration;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _fire();
        });

  bool _fired = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    HapticFeedback.heavyImpact();
    widget.onConfirmed?.call();
  }

  void _down() {
    if (widget.onConfirmed == null || widget.busy) return;
    _fired = false;
    HapticFeedback.selectionClick();
    _c.forward();
  }

  void _up() {
    if (_c.status == AnimationStatus.completed) return;
    // Releases faster than it fills, so an abandoned hold snaps back rather
    // than appearing to still be counting down.
    _c.reverse(from: _c.value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.colour ?? Brand.c500;
    final off = widget.onConfirmed == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 128,
            height: 128,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_c.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // The track the progress runs on.
                    CustomPaint(
                      size: const Size(128, 128),
                      painter: _RingPainter(
                        progress: 1,
                        colour: off
                            ? Coal.c100
                            : accent.withValues(alpha: 0.16),
                      ),
                    ),
                    CustomPaint(
                      size: const Size(128, 128),
                      painter: _RingPainter(
                          progress: t, colour: off ? Coal.c200 : accent),
                    ),
                    // Sinks slightly under the finger, so the hold is felt
                    // as well as seen.
                    Transform.scale(
                      scale: 1 - t * 0.055,
                      child: Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          color: off ? Coal.c100 : accent,
                          shape: BoxShape.circle,
                          boxShadow: off ? null : Shade.tinted(accent),
                        ),
                        child: widget.busy
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4, color: Colors.white),
                                ),
                              )
                            : Icon(widget.icon,
                                size: 38,
                                color: off ? Coal.c400 : Colors.white),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(widget.label,
            textAlign: TextAlign.center,
            style: Txt.cardTitle
                .copyWith(fontSize: 15, color: off ? Coal.c400 : Coal.c900)),
        if (widget.hint != null) ...[
          const SizedBox(height: 3),
          Text(widget.hint!,
              textAlign: TextAlign.center, style: Txt.meta),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.colour});

  final double progress;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final pen = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2 - 4),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      pen,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colour != colour;
}

/// The customer's side of the handshake: a professional is waiting on them.
///
/// Deliberately loud. It appears only when somebody is standing in the room
/// waiting for an answer, so it should be impossible to miss and take one
/// tap to clear.
class ApprovalPrompt extends StatelessWidget {
  const ApprovalPrompt({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.onDecline,
    this.declineLabel = 'Not yet',
    this.busy = false,
    this.icon = Icons.pan_tool_alt_rounded,
    this.colour,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onDecline;
  final String declineLabel;
  final bool busy;
  final IconData icon;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final accent = colour ?? Brand.c500;

    return Panel(
      padding: const EdgeInsets.all(Gap.xl),
      radius: Radii.panel,
      shadow: Shade.tinted(accent),
      border: Border.all(color: accent, width: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(title,
                    style: Txt.cardTitle.copyWith(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(body, style: Txt.body.copyWith(fontSize: 13.5)),
          const SizedBox(height: Gap.xl),
          Btn(confirmLabel, onTap: onConfirm, busy: busy, colour: accent),
          if (onDecline != null) ...[
            const SizedBox(height: Gap.sm),
            Btn(declineLabel, kind: BtnKind.ghost, onTap: onDecline),
          ],
        ],
      ),
    );
  }
}
