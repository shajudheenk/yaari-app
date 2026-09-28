import 'package:flutter/material.dart';
import 'theme.dart';

/// Brand mark on the diagonal planes used across both splash screens.
class YaariSplash extends StatelessWidget {
  const YaariSplash({super.key, required this.brand, required this.wordmark, this.strapline});

  final YaariBrand brand;
  final String wordmark;
  final String? strapline;

  @override
  Widget build(BuildContext context) {
    final deep = brand == YaariBrand.customer ? YaariColors.emberDeep : const Color(0xFF33474F);
    final front = brand == YaariBrand.customer ? YaariColors.ember : YaariColors.slate;

    return Scaffold(
      backgroundColor: deep,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PlanesPainter(front: front))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 26, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Icon(Icons.home_outlined, size: 32, color: front),
                ),
                const SizedBox(height: 16),
                Text(wordmark,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                if (strapline != null) ...[
                  const SizedBox(height: 8),
                  Text(strapline!.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xBBFFFFFF), fontSize: 10.5, letterSpacing: 2.6)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanesPainter extends CustomPainter {
  _PlanesPainter({required this.front});
  final Color front;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = YaariColors.sky.withValues(alpha: 0.85);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.56, 0)
        ..lineTo(0, size.height * 0.36)
        ..close(),
      sky,
    );

    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height * 0.56)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.30, size.height)
        ..close(),
      Paint()..color = front,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanesPainter old) => old.front != front;
}

/// Small status pill. Used for trade tags, live badges and compliance marks.
class YaariChip extends StatelessWidget {
  const YaariChip(this.label, {super.key, this.tone = YaariTone.neutral, this.dot = false});

  final String label;
  final YaariTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      YaariTone.good => (const Color(0xFFE6F4EC), YaariColors.good),
      YaariTone.warn => (const Color(0xFFFDF1DE), YaariColors.warn),
      YaariTone.bad => (YaariColors.emberTint, YaariColors.emberDeep),
      YaariTone.slate => (YaariColors.slateTint, YaariColors.slate),
      YaariTone.neutral => (YaariColors.chalk, YaariColors.inkDim),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

enum YaariTone { neutral, good, warn, bad, slate }

/// Circular trade icon used on the home grid.
class TradeIcon extends StatelessWidget {
  const TradeIcon({super.key, required this.icon, required this.tinted});

  final String icon;
  final bool tinted;

  static const _map = <String, IconData>{
    'bolt': Icons.bolt_outlined,
    'wrench': Icons.plumbing_outlined,
    'flame': Icons.local_fire_department_outlined,
    'hammer': Icons.handyman_outlined,
    'roller': Icons.format_paint_outlined,
    'broom': Icons.cleaning_services_outlined,
    'leaf': Icons.local_florist_outlined,
    'lock': Icons.lock_outline,
    'wheel': Icons.build_circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: tinted ? YaariColors.emberTint : YaariColors.slateTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        _map[icon] ?? Icons.home_repair_service_outlined,
        size: 25,
        color: tinted ? YaariColors.emberDeep : YaariColors.slate,
      ),
    );
  }
}

/// Consistent empty and error states — thin supply is normal here, so
/// these need to read as honest rather than broken.
class YaariEmpty extends StatelessWidget {
  const YaariEmpty({super.key, required this.title, required this.body, this.icon});

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.search_off, size: 34, color: YaariColors.inkDim),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
