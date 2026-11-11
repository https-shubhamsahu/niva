import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fitness/fitness_trial.dart';
import '../../core/fitness/one_leg_minute.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';
import '../../shared/widgets/health_layout.dart';
import 'station_providers.dart';

/// One-Leg Minute: a daily practice round. It is practice, not a test: no
/// score, no ranking, no claim that practice improves balance. The Fit India
/// protocol itself advises practising one-foot balance.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  final _roll = TextEditingController();
  OneLegMinuteRound _round = OneLegMinuteRound();
  Timer? _ticker;
  StreamSubscription? _events;
  bool _added = false;

  @override
  void initState() {
    super.initState();
    // The insole on the held foot ends a hold when it touches down.
    _events = ref.read(insoleEventsProvider).listen((timed) {
      final insole = ref.read(insoleStatusProvider);
      if (insole.mode != InsoleMode.watching) return;
      if (timed.event.isFoot && timed.event.isOn) _touchDown();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _events?.cancel();
    _roll.dispose();
    super.dispose();
  }

  int get _now => ref.read(monotonicClockProvider).nowMs;

  void _start() {
    setState(() {
      _round = OneLegMinuteRound()..start(_now);
      _added = false;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _round.tick(_now);
      if (_round.phase == OneLegPhase.finished) _finish();
      if (mounted) setState(() {});
    });
  }

  void _touchDown() {
    if (_round.phase != OneLegPhase.holding) return;
    setState(() => _round.touchDown(_now));
  }

  void _finish() {
    _ticker?.cancel();
    if (_added) return;
    _added = true;
    final id = _roll.text.trim().isEmpty ? 'unnamed' : _roll.text.trim();
    ref.read(classPracticeProvider.notifier).add(id, _round);
  }

  String _s(int ms) => (ms / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cls = ref.watch(classPracticeProvider);
    final now = _now;
    final phase = _round.phase;

    return Scaffold(
      appBar: AppBar(title: const Text('One-Leg Minute'), actions: [
        IconButton(
            tooltip: 'About practice',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => openHealthDetails(
                context,
                'Practice, not a test',
                const Text(
                    'Stand on one leg for a minute. Each touch-down ends a hold; step back up and go again. This records practice only, with no ranking or claim of improvement.'))),
      ]),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (phase == OneLegPhase.ready ||
                        phase == OneLegPhase.finished)
                      FilledButton(
                        onPressed: _start,
                        child: Text(phase == OneLegPhase.ready
                            ? 'Start the minute'
                            : 'Another round'),
                      )
                    else if (phase == OneLegPhase.holding)
                      OutlinedButton(
                        onPressed: _touchDown,
                        child: const Text('Foot touched down'),
                      )
                    else
                      FilledButton(
                        onPressed: () => setState(() => _round.resume(_now)),
                        child: const Text('Back on one leg'),
                      ),
                  ]))),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('One minute of practice. Step down, reset, and go again.',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _roll,
                  enabled: phase == OneLegPhase.ready ||
                      phase == OneLegPhase.finished,
                  decoration: const InputDecoration(
                    labelText: 'Roll ID (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                RoundedCard(
                    radius: 24,
                    child: Column(children: [
                      const SizedBox(height: 10),
                      SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(alignment: Alignment.center, children: [
                            Positioned.fill(
                                child: CircularProgressIndicator(
                                    value: (_round.elapsedMs(now) / 60000)
                                        .clamp(0, 1),
                                    strokeWidth: 7,
                                    strokeCap: StrokeCap.round,
                                    color: AppColors.brand,
                                    backgroundColor: theme.dividerColor)),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                  phase == OneLegPhase.ready
                                      ? 'Ready'
                                      : _s(_round.elapsedMs(now)),
                                  style: theme.textTheme.displayLarge),
                              Text('of 60 seconds',
                                  style: theme.textTheme.bodySmall),
                            ]),
                          ])),
                      const SizedBox(height: 20),
                      Text(
                          'Longest hold ${_s(_round.longestHoldMs)} s · touch-downs ${_round.touchDowns}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall),
                    ])),
                const SizedBox(height: 12),
                const SizedBox(height: 20),
                RoundedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This session, whole class',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                          '${cls.children} ${cls.children == 1 ? 'child' : 'children'} · ${_s(cls.totalPracticeMs)} s of one-leg practice together',
                          style: theme.textTheme.bodyMedium),
                      if (_roll.text.trim().isNotEmpty &&
                          cls.longestHoldMs(_roll.text.trim()) != null)
                        Text(
                            'Your own longest hold: ${_s(cls.longestHoldMs(_roll.text.trim())!)} s',
                            style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
