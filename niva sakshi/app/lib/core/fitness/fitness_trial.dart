import 'fit_india_protocol.dart';
import 'flamingo_session.dart';
import 'vrikshasana_session.dart';

/// What the insole could contribute when a trial started. A trial keeps
/// this for its whole run, so its record says plainly whether the insole
/// watched it or the tester ran it alone.
enum InsoleMode { watching, notConnected, notValid, noEvents }

extension InsoleModeText on InsoleMode {
  /// For a finished trial's record.
  String get label {
    switch (this) {
      case InsoleMode.watching:
        return 'The insole watched the raised foot.';
      case InsoleMode.notConnected:
        return 'No insole was connected; the tester ran this trial alone.';
      case InsoleMode.notValid:
        return 'The insole was not tared; the tester ran this trial alone.';
      case InsoleMode.noEvents:
        return 'The insole firmware had no contact events; the tester ran this trial alone.';
    }
  }

  /// For the current state, before or during a trial.
  String get now {
    switch (this) {
      case InsoleMode.watching:
        return 'Insole watching the raised foot.';
      case InsoleMode.notConnected:
        return 'No insole connected. The tester times and counts alone.';
      case InsoleMode.notValid:
        return 'Insole not tared. The tester times and counts alone.';
      case InsoleMode.noEvents:
        return 'Insole firmware has no contact events. The tester times and counts alone.';
    }
  }

  String get wireValue => name;
}

/// The insole as the Tests screens need to see it.
class InsoleStatus {
  final bool connected;
  final bool valid;
  final bool reportsEvents;

  /// Firmware contact mask: any bit set means the raised foot reads loaded.
  final int contactMask;

  const InsoleStatus({
    required this.connected,
    required this.valid,
    required this.reportsEvents,
    required this.contactMask,
  });

  static const disconnected = InsoleStatus(
      connected: false, valid: false, reportsEvents: false, contactMask: 0);

  InsoleMode get mode {
    if (!connected) return InsoleMode.notConnected;
    if (!valid) return InsoleMode.notValid;
    if (!reportsEvents) return InsoleMode.noEvents;
    return InsoleMode.watching;
  }

  bool get footLoaded => contactMask != 0;
}

/// One finished trial: one participant, one test, one standing leg.
class FitnessTrial {
  final String id;
  final FitnessTest test;
  final String participantId;
  final String sessionId;
  final StandingLeg standingLeg;
  final DateTime startedAt;
  final InsoleMode insoleMode;

  // Flamingo.
  final List<BalanceLoss> losses;
  final int? balanceMs;
  final bool terminatedEarly;

  // Vrikshasana.
  final int? holdMs;
  final HoldEnd? holdEnd;
  final int? holdEndDeviceMs;
  final List<int> dismissedEndsAtMs;

  const FitnessTrial({
    required this.id,
    required this.test,
    required this.participantId,
    required this.sessionId,
    required this.standingLeg,
    required this.startedAt,
    required this.insoleMode,
    this.losses = const [],
    this.balanceMs,
    this.terminatedEarly = false,
    this.holdMs,
    this.holdEnd,
    this.holdEndDeviceMs,
    this.dismissedEndsAtMs = const [],
  });

  int get falls => losses.where((l) => l.counted).length;
  int get insoleConfirmed =>
      losses.where((l) => l.source == LossSource.insoleConfirmed).length;
  int get insoleDismissed =>
      losses.where((l) => l.source == LossSource.insoleDismissed).length;
  int get testerOnly =>
      losses.where((l) => l.source == LossSource.tester).length;
  int get beamConfirmed =>
      losses.where((l) => l.source == LossSource.beamConfirmed).length;
  int get beamDismissed =>
      losses.where((l) => l.source == LossSource.beamDismissed).length;
  bool get holdBelowMinimum =>
      holdMs != null && holdMs! < VrikshasanaRules.minHoldMs;

  /// The protocol's score, in words.
  String get scoreLabel {
    switch (test) {
      case FitnessTest.flamingo:
        final noun = falls == 1 ? 'fall' : 'falls';
        return terminatedEarly ? '$falls $noun, stopped early' : '$falls $noun';
      case FitnessTest.vrikshasana:
        return '${formatSeconds(holdMs ?? 0)} s hold';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'test': test.wireValue,
        'participantId': participantId,
        'sessionId': sessionId,
        'standingLeg': standingLeg.name,
        'startedAt': startedAt.toIso8601String(),
        'insoleMode': insoleMode.wireValue,
        'losses': [
          for (final l in losses)
            {'atMs': l.atMs, 'deviceMs': l.deviceMs, 'source': l.source.code},
        ],
        'balanceMs': balanceMs,
        'terminatedEarly': terminatedEarly,
        'holdMs': holdMs,
        'holdEnd': holdEnd?.wireValue,
        'holdEndDeviceMs': holdEndDeviceMs,
        'dismissedEndsAtMs': dismissedEndsAtMs,
      };

  static FitnessTrial fromMap(Map<dynamic, dynamic> map) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    final rawLosses = map['losses'];
    final losses = <BalanceLoss>[];
    if (rawLosses is List) {
      for (final raw in rawLosses) {
        if (raw is! Map) continue;
        final source = LossSourceWire.fromCode('${raw['source']}');
        final atMs = (raw['atMs'] as num?)?.toInt();
        if (source == null || atMs == null) continue;
        losses.add(BalanceLoss(
          atMs: atMs,
          deviceMs: (raw['deviceMs'] as num?)?.toInt(),
          source: source,
        ));
      }
    }
    final rawHoldEnd = map['holdEnd'];
    final rawDismissed = map['dismissedEndsAtMs'];

    return FitnessTrial(
      id: map['id'] as String,
      test: byName(FitnessTest.values, map['test'], FitnessTest.flamingo),
      participantId: map['participantId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      standingLeg:
          byName(StandingLeg.values, map['standingLeg'], StandingLeg.left),
      startedAt: DateTime.tryParse(map['startedAt'] as String? ?? '') ??
          DateTime(1970),
      insoleMode:
          byName(InsoleMode.values, map['insoleMode'], InsoleMode.notConnected),
      losses: losses,
      balanceMs: (map['balanceMs'] as num?)?.toInt(),
      terminatedEarly: map['terminatedEarly'] == true,
      holdMs: (map['holdMs'] as num?)?.toInt(),
      holdEnd: rawHoldEnd == null
          ? null
          : byName(HoldEnd.values, rawHoldEnd, HoldEnd.tester),
      holdEndDeviceMs: (map['holdEndDeviceMs'] as num?)?.toInt(),
      dismissedEndsAtMs: rawDismissed is List
          ? rawDismissed.whereType<num>().map((n) => n.toInt()).toList()
          : const [],
    );
  }

  static const csvHeader =
      'trialId,test,participantId,sessionId,standingLeg,startedAt,insoleMode,'
      'falls,balanceMs,terminatedEarly,insoleConfirmed,insoleDismissed,testerOnly,losses,'
      'holdMs,holdEnd,holdEndDeviceMs,dismissedEndsAtMs,lossDeviceMs,beamConfirmed,beamDismissed';

  /// `losses` is `source@balanceMs` per entry (C insole confirmed,
  /// D insole dismissed, T tester only, B beam confirmed, X beam dismissed), space-separated, so agreement
  /// between the insole and the tester can be computed from the export.
  /// `lossDeviceMs` is the insole's own clock for each loss, in the same
  /// order as `losses` (`-` for a tester-only loss), so a trial lines up with
  /// the telemetry CSV and with video from this one file.
  String toCsvRow() {
    String esc(Object? value) {
      final text = value?.toString() ?? '';
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    final flamingo = test == FitnessTest.flamingo;
    return [
      esc(id),
      esc(test.wireValue),
      esc(participantId),
      esc(sessionId),
      esc(standingLeg.name),
      esc(startedAt.toIso8601String()),
      esc(insoleMode.wireValue),
      esc(flamingo ? falls : null),
      esc(balanceMs),
      esc(flamingo ? terminatedEarly : null),
      esc(flamingo ? insoleConfirmed : null),
      esc(flamingo ? insoleDismissed : null),
      esc(flamingo ? testerOnly : null),
      esc(losses.map((l) => '${l.source.code}@${l.atMs}').join(' ')),
      esc(holdMs),
      esc(holdEnd?.wireValue),
      esc(holdEndDeviceMs),
      esc(dismissedEndsAtMs.join(' ')),
      esc(losses.map((l) => l.deviceMs?.toString() ?? '-').join(' ')),
      esc(flamingo ? beamConfirmed : null),
      esc(flamingo ? beamDismissed : null),
    ].join(',');
  }
}

/// `12345` ms as `12.3`.
String formatSeconds(int ms) => (ms / 1000).toStringAsFixed(1);
