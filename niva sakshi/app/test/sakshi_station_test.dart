import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/fitness/agreement_summary.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/fitness/flamingo_session.dart';
import 'package:niva/core/fitness/one_leg_minute.dart';
import 'package:niva/core/fitness/roster.dart';

/// Synthetic sequences that exercise the station logic. They say nothing
/// about how well the beam or the insole match a real foot; the agreement
/// study measures that.
void main() {
  group('beam as a flag source', () {
    test('a confirmed beam flag is counted and recorded as B', () {
      final s = FlamingoSession()..start(0);
      expect(s.beamLoss(eventMs: 8000, deviceMs: 700, nowMs: 8100), isTrue);
      expect(s.phase, FlamingoPhase.checking);
      s.confirmFlag();
      expect(s.falls, 1);
      expect(s.beamConfirmed, 1);
      expect(s.insoleConfirmed, 0);
      expect(s.losses.single.source.code, 'B');
    });

    test('a dismissed beam flag is kept, not counted, and the clock runs on',
        () {
      final s = FlamingoSession()..start(0);
      s.beamLoss(eventMs: 8000, deviceMs: 700, nowMs: 8050);
      s.dismissFlag(12000);
      expect(s.falls, 0);
      expect(s.beamDismissed, 1);
      expect(s.losses.single.source.code, 'X');
      expect(s.balanceMs(12000), 12000);
    });

    test('a second witness flag during a check is ignored', () {
      final s = FlamingoSession()..start(0);
      expect(s.insoleLoss(eventMs: 5000, deviceMs: 1, nowMs: 5010), isTrue);
      expect(s.beamLoss(eventMs: 5020, deviceMs: 2, nowMs: 5030), isFalse);
      s.confirmFlag();
      expect(s.insoleConfirmed, 1);
      expect(s.beamConfirmed, 0);
    });

    test('beam codes survive storage and reach the CSV', () {
      final trial = FitnessTrial(
        id: 't',
        test: FitnessTest.flamingo,
        participantId: '12',
        sessionId: 's',
        standingLeg: StandingLeg.left,
        startedAt: DateTime(2026, 10, 2),
        insoleMode: InsoleMode.notConnected,
        losses: const [
          BalanceLoss(
              atMs: 3000, deviceMs: 903000, source: LossSource.beamConfirmed),
          BalanceLoss(
              atMs: 6000, deviceMs: 906000, source: LossSource.beamDismissed),
        ],
        balanceMs: 60000,
      );
      final back = FitnessTrial.fromMap(trial.toMap());
      expect(back.beamConfirmed, 1);
      expect(back.beamDismissed, 1);
      expect(back.falls, 1);
      final row = trial.toCsvRow();
      expect(row, contains('B@3000 X@6000'));
      expect(row, endsWith(',903000 906000,1,1'));
      expect(row.split(',').length, FitnessTrial.csvHeader.split(',').length);
    });
  });

  group('AgreementSummary', () {
    test('counts by witness and reports no percentage', () {
      FitnessTrial trial(List<BalanceLoss> losses) => FitnessTrial(
            id: '${losses.length}',
            test: FitnessTest.flamingo,
            participantId: 'a',
            sessionId: 's',
            standingLeg: StandingLeg.left,
            startedAt: DateTime(2026, 10, 2),
            insoleMode: InsoleMode.watching,
            losses: losses,
            balanceMs: 60000,
          );
      final summary = AgreementSummary.of([
        trial(const [
          BalanceLoss(atMs: 1000, source: LossSource.insoleConfirmed),
          BalanceLoss(atMs: 2000, source: LossSource.insoleDismissed),
          BalanceLoss(atMs: 3000, source: LossSource.tester),
        ]),
        trial(const [
          BalanceLoss(atMs: 1000, source: LossSource.beamConfirmed),
        ]),
      ]);
      expect(summary.trials, 2);
      expect(summary.flaggedAndCounted, 2);
      expect(summary.flaggedAndDismissed, 1);
      expect(summary.testerOnly, 1);
      expect(summary.insoleFlags, 2);
      expect(summary.beamFlags, 1);
      expect(summary.countedFalls, 3);
    });
  });

  group('Roster', () {
    test('keeps roll IDs only, drops blanks and duplicates, queues in order',
        () {
      final r = Roster.parse('12, 7\n\n12;9 ');
      expect(r.all, ['12', '7', '9']);
      expect(r.next, '12');
      r.markDone('12');
      expect(r.next, '7');
      r.markDone('nobody');
      expect(r.doneCount, 1);
      r.markDone('7');
      r.markDone('9');
      expect(r.finished, isTrue);
      expect(r.next, isNull);
      r.reopen('7');
      expect(r.next, '7');
      final back = Roster.fromMap(r.toMap());
      expect(back.doneCount, 2);
      expect(back.next, '7');
    });
  });

  group('One-Leg Minute', () {
    test('tracks holds, touch-downs and the longest hold over 60 s', () {
      final r = OneLegMinuteRound()..start(0);
      r.touchDown(20000); // first hold 20 s
      expect(r.touchDowns, 1);
      expect(r.phase, OneLegPhase.down);
      r.resume(25000);
      r.touchDown(30000); // second hold 5 s
      r.resume(32000);
      r.tick(60000); // third hold 28 s, cut by the clock
      expect(r.phase, OneLegPhase.finished);
      expect(r.longestHoldMs, 28000);
      expect(r.heldMs, 20000 + 5000 + 28000);
      expect(r.touchDowns, 2);
      expect(r.elapsedMs(99999), OneLegMinuteRules.roundMs);
    });

    test('the class total adds time and keeps only each child\'s own best', () {
      final a = OneLegMinuteRound()..start(0);
      a.tick(60000);
      final b = OneLegMinuteRound()..start(0);
      b.touchDown(10000);
      b.resume(11000);
      b.tick(60000);
      final c = ClassPractice()
        ..add('1', a)
        ..add('2', b);
      expect(c.children, 2);
      expect(c.totalPracticeMs, 60000 + 10000 + 49000);
      expect(c.longestHoldMs('1'), 60000);
      expect(c.longestHoldMs('2'), 49000);
    });

    test('unfinished rounds are not added to the class', () {
      final a = OneLegMinuteRound()..start(0);
      final c = ClassPractice()..add('1', a);
      expect(c.children, 0);
    });
  });
}
