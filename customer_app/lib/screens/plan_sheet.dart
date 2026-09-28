import 'package:flutter/material.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../plan.dart';

/// A standing arrangement, summarised in a card.
///
/// It has to answer three questions at a glance — what, who, and when next —
/// because that is what a customer checks when they wonder whether they still
/// have a cleaner coming on Tuesday.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onTap});

  final RepeatPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paused = plan.isPaused;

    return YaariPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Surface.raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: paused ? Coal.c100 : Brand.c500,
            width: paused ? 1 : 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(paused ? Icons.pause_circle_outline : Icons.repeat_rounded,
                    size: 18,
                    color: paused ? Coal.c500 : Brand.c700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ),
                if (paused)
                  const YaariChip('Paused', tone: YaariTone.neutral)
                else
                  Text(
                    formatRate(plan.ratePence, plan.rateUnit),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Brand.c700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(plan.rhythm, style: text.bodySmall),
            const SizedBox(height: 4),
            Text(
              paused
                  ? 'Nothing is booked while this is paused.'
                  : plan.providerName != null
                      ? 'Next: ${_when(plan.nextDueAt)} · ${plan.providerName} first'
                      : 'Next: ${_when(plan.nextDueAt)}',
              style: text.bodySmall?.copyWith(
                color: paused ? Coal.c500 : Brand.c700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _when(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Pause, resume or end a plan.
///
/// Returns true when something changed, so the caller knows to reload.
/// Stopping and pausing both cancel the visit already in the diary — leaving
/// it behind would be a tradesperson turning up to a job the customer thinks
/// they called off — and the sheet says so before either happens.
Future<bool?> showPlanSheet(BuildContext context, RepeatPlan plan) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Surface.canvas,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PlanSheet(plan: plan),
  );
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({required this.plan});

  final RepeatPlan plan;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      Buzz.commit();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      Buzz.reject();
      setState(() {
        _busy = false;
        _error = 'Could not change the plan just now. Please try again.';
      });
    }
  }

  Future<void> _confirmEnd() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('End this plan?'),
        content: Text(
          'No more visits will be booked, and the one already in the diary '
          'for ${PlanCard._when(widget.plan.nextDueAt)} will be cancelled. '
          'You can set up a new plan whenever you like.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Brand.c500),
            child: const Text('End plan'),
          ),
        ],
      ),
    );
    if (sure == true) await _run(() => PlanApi.end(widget.plan.id));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = widget.plan;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Coal.c100,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(plan.serviceName, style: text.headlineMedium),
          const SizedBox(height: 4),
          Text(plan.rhythm, style: text.bodySmall),
          const SizedBox(height: 2),
          Text(plan.addressLine, style: text.bodySmall),
          const SizedBox(height: 16),

          if (plan.isPaused)
            Text(
              'Paused. Nothing is booked until you start it again.',
              style: text.bodySmall,
            )
          else
            Text(
              'Next visit ${PlanCard._when(plan.nextDueAt)}'
              '${plan.providerName != null ? ', offered to ${plan.providerName} first' : ''}.',
              style: text.bodySmall,
            ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: text.bodySmall?.copyWith(color: Brand.c500)),
          ],

          const SizedBox(height: 18),
          if (plan.isPaused)
            FilledButton(
              onPressed:
                  _busy ? null : () => _run(() => PlanApi.resume(plan.id)),
              child: const Text('Start it again'),
            )
          else
            OutlinedButton(
              onPressed:
                  _busy ? null : () => _run(() => PlanApi.pause(plan.id)),
              child: const Text('Pause this plan'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _confirmEnd,
            style: TextButton.styleFrom(foregroundColor: Brand.c500),
            child: const Text('End this plan'),
          ),
          const SizedBox(height: 4),
          Text(
            'No contract, no notice period, nothing to pay for stopping.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
