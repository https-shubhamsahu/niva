import 'package:flutter_test/flutter_test.dart';
import 'package:niva/core/fitness/fit_india_protocol.dart';
import 'package:niva/core/fitness/fitness_trial.dart';
import 'package:niva/core/fitness/flamingo_session.dart';
import 'package:niva/core/fitness/vrikshasana_session.dart';
import 'package:niva/core/time/clock.dart';

/// The rules under test come from the Fit India 18-65 protocol: the
/// Flamingo test on p. 24 and Vrikshasana on p. 23.
void main() {
  group('FlamingoSession (p. 24)', () {
    test('counts balancing time only while running, and stops at 60 s', () {
      final s = FlamingoSession()..start(0);
      expect(s.balanceMs(10000), 10000);
      s.testerLoss(10000); // fall at 10 s: clock pauses
      expect(s.phase, FlamingoPhase.paused);
      expect(s.balanceMs(25000),
          10000); // time spent getting back up is not balancing
      s.resume(25000);
      s.tick(74999);
      expect(s.phase, FlamingoPhase.running);
      s.tick(75000); // 10 s + 50 s = 60 s of balancing
      expect(s.phase, FlamingoPhase.finished);
      expect(s.balanceMs(90000), FlamingoRules.balanceMs);
      expect(s.falls, 1);
    });

    test('more than 15 falls in the first 30 s ends the test', () {
      final s = FlamingoSession()..start(0);
      var now = 0;
      for (var i = 0; i < 15; i++) {
        now += 1000;
        s.testerLoss(now);
        s.resume(now);
      }
      expect(s.phase, FlamingoPhase.running); // exactly 15 is allowed
      now += 1000;
      s.testerLoss(now); // the 16th, at 16 s
      expect(s.phase, FlamingoPhase.finished);
      expect(s.terminatedEarly, isTrue);
      expect(s.falls, 16);
    });

    test('falls after the first 30 s do not trigger early termination', () {
      final s = FlamingoSession()..start(0);
      var now = 31000;
      for (var i = 0; i < 20; i++) {
        s.testerLoss(now);
        s.resume(now);
        now += 100;
      }
      expect(s.terminatedEarly, isFalse);
    });

    test('a confirmed insole flag is counted at the flagged moment', () {
      final s = FlamingoSession()..start(0);
      final flagged =
          s.insoleLoss(eventMs: 12000, deviceMs: 512000, nowMs: 12150);
      expect(flagged, isTrue);
      expect(s.phase, FlamingoPhase.checking);
      expect(s.flaggedAtMs, 12000); // not the later arrival time
      s.confirmFlag();
      expect(s.phase, FlamingoPhase.paused);
      expect(s.falls, 1);
      expect(s.insoleConfirmed, 1);
      expect(s.losses.single.deviceMs, 512000);
    });

    test(
        'a dismissed flag is recorded, not counted, and costs no balancing time',
        () {
      final s = FlamingoSession()..start(0);
      s.insoleLoss(eventMs: 12000, deviceMs: 1, nowMs: 12100);
      s.dismissFlag(20000); // the tester took 8 s to decide
      expect(s.phase, FlamingoPhase.running);
      expect(s.falls, 0);
      expect(s.insoleDismissed, 1);
      expect(s.balanceMs(20000), 20000); // the participant kept balancing
    });

    test('a touchdown from before the instructor let go is ignored', () {
      final s = FlamingoSession()..start(5000);
      expect(s.insoleLoss(eventMs: 4900, deviceMs: 1, nowMs: 5050), isFalse);
      expect(s.phase, FlamingoPhase.running);
    });

    test('insole flags outside the running clock are ignored', () {
      final s = FlamingoSession();
      expect(s.insoleLoss(eventMs: 0, deviceMs: 1, nowMs: 0), isFalse);
      s.start(0);
      s.testerLoss(1000);
      expect(s.insoleLoss(eventMs: 1500, deviceMs: 1, nowMs: 1500),
          isFalse); // paused
      expect(s.phase, FlamingoPhase.paused);
    });
  });

  group('VrikshasanaSession (p. 23)', () {
    test('the tester stops the hold', () {
      final s = VrikshasanaSession()..start(1000);
      s.testerStop(24400);
      expect(s.phase, HoldPhase.finished);
      expect(s.holdMs(99999), 23400);
      expect(s.end, HoldEnd.tester);
      expect(s.belowMinimum, isFalse);
    });

    test('the hold stops by itself at 60 s', () {
      final s = VrikshasanaSession()..start(0);
      s.tick(59999);
      expect(s.phase, HoldPhase.holding);
      s.tick(60000);
      expect(s.phase, HoldPhase.finished);
      expect(s.end, HoldEnd.timeLimit);
      expect(s.holdMs(70000), VrikshasanaRules.maxHoldMs);
    });

    test('a confirmed insole end fixes the hold at the flagged moment', () {
      final s = VrikshasanaSession()..start(1000);
      expect(s.insoleEnd(eventMs: 13000, deviceMs: 77, nowMs: 13200), isTrue);
      expect(s.phase, HoldPhase.checking);
      expect(s.holdMs(15000), 14000); // the clock keeps running while checking
      s.confirmFlag();
      expect(s.holdMs(99999), 12000);
      expect(s.end, HoldEnd.insole);
      expect(s.endDeviceMs, 77);
    });

    test('a rejected insole end is recorded and the hold continues', () {
      final s = VrikshasanaSession()..start(0);
      s.insoleEnd(eventMs: 8000, deviceMs: 1, nowMs: 8100);
      s.dismissFlag(9000);
      expect(s.phase, HoldPhase.holding);
      expect(s.dismissedAtMs, [8000]);
      s.testerStop(30000);
      expect(s.holdMs(99999), 30000);
    });

    test('a hold under 10 s is marked for a restart', () {
      final s = VrikshasanaSession()..start(0);
      s.testerStop(6500);
      expect(s.belowMinimum, isTrue);
    });
  });

  group('ClockSync', () {
    test('maps insole time with the smallest recent offset', () {
      final sync = ClockSync();
      expect(sync.toPhone(100), isNull);
      sync.observe(deviceMs: 1000, phoneMs: 5080); // offset 4000 + 80 ms delay
      sync.observe(deviceMs: 1050, phoneMs: 5070); // offset 4000 + 20 ms delay
      sync.observe(deviceMs: 1100, phoneMs: 5160);
      expect(sync.toPhone(1060), 1060 + 4020);
    });

    test('forgets old offsets when the insole restarts', () {
      final sync = ClockSync();
      sync.observe(deviceMs: 90000, phoneMs: 100000);
      sync.observe(deviceMs: 10, phoneMs: 100500); // clock went backwards
      expect(sync.toPhone(20), 20 + 100490);
    });
  });

  group('FitnessTrial', () {
    final trial = FitnessTrial(
      id: 't1',
      test: FitnessTest.flamingo,
      participantId: 'R-12, B',
      sessionId: 'session-2026-10-01',
      standingLeg: StandingLeg.right,
      startedAt: DateTime(2026, 10, 1, 9, 30),
      insoleMode: InsoleMode.watching,
      losses: const [
        BalanceLoss(
            atMs: 4000, deviceMs: 1004000, source: LossSource.insoleConfirmed),
        BalanceLoss(
            atMs: 9000, deviceMs: 1009000, source: LossSource.insoleDismissed),
        BalanceLoss(atMs: 20000, source: LossSource.tester),
      ],
      balanceMs: 60000,
    );

    test('survives a storage round trip', () {
      final back = FitnessTrial.fromMap(trial.toMap());
      expect(back.falls, 2);
      expect(back.insoleConfirmed, 1);
      expect(back.insoleDismissed, 1);
      expect(back.testerOnly, 1);
      expect(back.standingLeg, StandingLeg.right);
      expect(back.losses.first.deviceMs, 1004000);
      expect(back.scoreLabel, '2 falls');
    });

    test('exports one CSV row with the agreement record', () {
      final row = trial.toCsvRow();
      expect(row, contains('"R-12, B"')); // quoted because of the comma
      expect(row, contains('C@4000 D@9000 T@20000'));
      expect(row.split(',').length,
          greaterThanOrEqualTo(FitnessTrial.csvHeader.split(',').length));
    });
  });
}
