import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feel.dart';
import 'media.dart';
import 'marks.dart';
import 'theme.dart';

/// The register: ruled rows instead of floating cards.
///
/// A rounded card with a shadow says "product tile, one of many, buy me". A
/// row under a rule says "entry in a list that is maintained". The second is
/// what Yaari actually is, and it is the one thing no competitor's interface
/// says — they are all shop fronts.
///
/// Practically it also reads better: a full-width row fits the whole trade
/// name, a line of description and a right-aligned price, where a third-width
/// tile fits a cropped photograph and a truncated label.

/// The hard rule that opens a register, and the hairlines between its rows.
///
/// Two weights only. The heavy rule is structural — it says a list starts
/// here; the hairline is just separation.
class YaariRule extends StatelessWidget {
  const YaariRule({super.key, this.heavy = false});

  final bool heavy;

  @override
  Widget build(BuildContext context) => Container(
        height: heavy ? 1.5 : 1,
        color: heavy ? YaariColors.ink : YaariColors.line,
      );
}

/// One entry: mark, name, description, figure.
///
/// The figure is tabular so that a column of prices lines up on the decimal
/// the way a printed register does. It is the cheapest possible signal that
/// somebody has been careful with the numbers.
class YaariRegisterRow extends StatefulWidget {
  const YaariRegisterRow({
    super.key,
    required this.markSlug,
    required this.title,
    this.subtitle,
    this.figure,
    this.figureNote,
    this.trailing,
    this.onTap,
    this.accent = YaariColors.ember,
    this.dense = false,
    this.heroTag,
  });

  final String markSlug;
  final String title;
  final String? subtitle;

  /// Right-aligned, tabular. Usually a price.
  final String? figure;

  /// Small text under the figure — "from", "per visit".
  final String? figureNote;

  /// Replaces the figure entirely when a row needs something richer.
  final Widget? trailing;

  final VoidCallback? onTap;
  final Color accent;
  final bool dense;

  /// When set, the mark flies into the next screen's header rather than the
  /// two screens simply cross-fading.
  final Object? heroTag;

  @override
  State<YaariRegisterRow> createState() => _YaariRegisterRowState();
}

class _YaariRegisterRowState extends State<YaariRegisterRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final markSize = widget.dense ? 26.0 : 32.0;

    Widget mark = YaariMark(
      widget.markSlug,
      size: markSize,
      accent: widget.accent,
    );
    if (widget.heroTag != null) {
      mark = Hero(tag: widget.heroTag!, child: mark);
    }

    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        // A row is part of the page, so pressing it should push it into the
        // page rather than lift it off. Tinting the ground reads as pressure;
        // scaling reads as a button that escaped its own screen.
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        color: _down ? YaariColors.line.withValues(alpha: 0.5) : Colors.transparent,
        padding: EdgeInsets.fromLTRB(2, widget.dense ? 10 : 13, 2, widget.dense ? 10 : 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            mark,
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.dense ? 13.5 : 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      height: 1.2,
                      color: YaariColors.ink,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 10),
              widget.trailing!,
            ] else if (widget.figure != null) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.figure!,
                    style: TextStyle(
                      fontSize: widget.dense ? 12.5 : 13.5,
                      fontWeight: FontWeight.w800,
                      color: widget.accent == YaariColors.ember
                          ? YaariColors.emberDeep
                          : widget.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (widget.figureNote != null)
                    Text(
                      widget.figureNote!,
                      style: text.bodySmall?.copyWith(fontSize: 10),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A list of register rows with the rules already drawn between them.
class YaariRegister extends StatelessWidget {
  const YaariRegister({super.key, required this.children, this.stagger = true});

  final List<Widget> children;

  /// Rows rise into place one just after the next, so the list assembles top
  /// to bottom rather than appearing all at once.
  final bool stagger;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[const YaariRule(heavy: true)];
    for (var i = 0; i < children.length; i++) {
      rows.add(
        stagger
            ? YaariReveal(
                delay: Duration(milliseconds: 34 * i),
                child: children[i],
              )
            : children[i],
      );
      rows.add(const YaariRule());
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// The seal: a drawn shield and tick, with the number of checked people
/// behind it.
///
/// The only ornament in the app, and it is earned — the figure is counted
/// from the compliance gate on every load, not typed into a design.
class YaariSeal extends StatelessWidget {
  const YaariSeal({
    super.key,
    required this.label,
    this.accent = YaariColors.ember,
    this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.fromLTRB(7, 3.5, 10, 3.5),
      decoration: BoxDecoration(
        border: Border.all(color: accent, width: 1.4),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CustomPaint(painter: _SealPainter(accent)),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: accent == YaariColors.ember ? YaariColors.emberDeep : accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return GestureDetector(
      onTap: () {
        Buzz.tap();
        onTap!();
      },
      child: body,
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.scale(s);

    final pen = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.drawPath(
      Path()
        ..moveTo(12, 3)
        ..lineTo(19, 6)
        ..lineTo(19, 11)
        ..cubicTo(19, 15.5, 16, 19, 12, 21)
        ..cubicTo(8, 19, 5, 15.5, 5, 11)
        ..lineTo(5, 6)
        ..close(),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, 12)
        ..lineTo(11, 14)
        ..lineTo(15, 10),
      pen,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.colour != colour;
}

/// A screen opener: the place name in Fraunces, a line of context under it,
/// and the seal on the right.
///
/// Type carries the hierarchy here rather than a box, which is most of the
/// difference between an app that feels considered and one that feels
/// assembled from components.
class YaariMasthead extends StatelessWidget {
  const YaariMasthead({
    super.key,
    required this.title,
    required this.subtitle,
    this.seal,
    this.onTapTitle,
  });

  final String title;
  final String subtitle;
  final Widget? seal;
  final VoidCallback? onTapTitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onTapTitle == null
                    ? null
                    : () {
                        Buzz.tap();
                        onTapTitle!();
                      },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.displaySmall,
                      ),
                    ),
                    if (onTapTitle != null) ...[
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Icon(Icons.expand_more,
                            size: 20, color: YaariColors.inkDim),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (seal != null) ...[
              const SizedBox(width: 10),
              Padding(padding: const EdgeInsets.only(bottom: 5), child: seal!),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: text.bodySmall?.copyWith(fontSize: 12)),
      ],
    );
  }
}

/// Where you are in the booking funnel.
///
/// Wecasa's funnel works because every screen answers one question and the
/// rail tells you how many are left. Yaari's four steps were unlabelled, so
/// choosing a service felt like it might be the last thing before being
/// charged. A rail costs almost nothing and removes that.
class YaariProgressRail extends StatelessWidget {
  const YaariProgressRail({
    super.key,
    required this.step,
    required this.of,
    required this.label,
    this.accent = YaariColors.ember,
  });

  /// 1-based.
  final int step;
  final int of;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= of; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: YaariCurves.settleDuration,
                  curve: YaariCurves.settle,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= step ? accent : YaariColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < of) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              'STEP $step OF $of',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: accent == YaariColors.ember
                    ? YaariColors.emberDeep
                    : accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The bar that sits on the bottom of a funnel screen: what it will cost on
/// the left, what happens next on the right.
///
/// Lifting the figure out of the page and pinning it means the price is never
/// something you have to scroll back to check — which is the single thing
/// every booking funnel in this category gets right and Yaari did not.
class YaariFunnelBar extends StatelessWidget {
  const YaariFunnelBar({
    super.key,
    required this.label,
    required this.figure,
    this.wasFigure,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
    this.accent = YaariColors.ember,
  });

  /// What the figure means — "Fixed price", "Every week, per visit".
  final String label;
  final String figure;

  /// Struck through beside the figure when a plan has brought the price down.
  final String? wasFigure;

  final String actionLabel;

  /// Null disables the button, for a step that is not yet answered.
  final VoidCallback? onAction;

  final bool busy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: YaariColors.card,
        border: Border(top: BorderSide(color: YaariColors.ink, width: 1.5)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 13, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                if (wasFigure != null) ...[
                  Text(
                    wasFigure!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: YaariColors.inkDim,
                      decoration: TextDecoration.lineThrough,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  figure,
                  style: TextStyle(
                    fontFamily: YaariType.display,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -0.5,
                    color: accent == YaariColors.ember
                        ? YaariColors.emberDeep
                        : accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            FilledButton(
              onPressed: busy ? null : onAction,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
