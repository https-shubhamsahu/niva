import '../models/biomechanics_metrics.dart';
import '../providers/telemetry_state.dart';

/// Generates plain-English answers to a fixed set of gait-analysis
/// questions, built entirely from data already live in [TelemetryState] /
/// [ProcessedBiomechanicsMetrics] - the same thresholds
/// `insights_screen.dart`'s Clinical Summary and "Why These Alerts Fire"
/// card already surface, just addressed conversationally.
///
/// Deliberately NOT calling any LLM API: no network dependency, no API key,
/// no latency/failure risk during a live demo, and it keeps the app's
/// "explainable, not black-box" promise literally true of the coach too.
/// This interface is exactly the seam where a real LLM call would go if
/// this is ever swapped for one - nothing above it (the UI) would change.
abstract class AiCoachService {
  String answer(String question, TelemetryState snapshot);
}

class TemplatedAiCoachService implements AiCoachService {
  const TemplatedAiCoachService();

  @override
  String answer(String question, TelemetryState snapshot) {
    final q = question.toLowerCase();
    final metrics = snapshot.metrics;

    if (!snapshot.isLive) {
      return "I don't have a live stream to read yet - connect the insole or start a simulation on the Today tab, then ask me again.";
    }
    if (!metrics.isCalibrated) {
      return 'Still calibrating the baseline - keep the foot unloaded for a few seconds, then ask me again once a live reading settles in.';
    }

    if (_matches(q, ['stability', 'stable'])) return _stabilityAnswer(metrics);
    if (_matches(q, ['focus', 'what should i', 'improve', 'today'])) return _focusAnswer(metrics);
    if (_matches(q, ['mlpi', 'medial', 'lateral'])) return _mlpiAnswer(metrics);
    if (_matches(q, ['anomal', 'flag', 'wrong', 'issue', 'risk', 'ischemic'])) return _anomalyAnswer(metrics);
    if (_matches(q, ['cadence', 'steps per minute', 'spm', 'pace'])) return _cadenceAnswer(metrics);

    return _generalAnswer();
  }

  bool _matches(String q, List<String> keywords) => keywords.any(q.contains);

  String _stabilityAnswer(ProcessedBiomechanicsMetrics m) {
    final band = m.stabilityBand.label.toLowerCase();
    String reason = '';
    if (m.anomalyFlags.isNotEmpty) {
      reason = ' mainly because of: ${m.anomalyFlags.first.toLowerCase()}';
    } else if (m.stabilityBand != StabilityBand.stable) {
      reason = ' driven by sway of ${m.stabilityMagnitude.toStringAsFixed(1)}° '
          'and impact load at ${(m.impactLevel * 100).round()}%';
    }
    return 'Your stability score is ${m.stabilityScore}/100, in the $band band$reason. '
        'Stability combines sway magnitude and impact severity - lower sway and gentler footfalls both push this up.';
  }

  String _focusAnswer(ProcessedBiomechanicsMetrics m) {
    if (m.anomalyFlags.isNotEmpty) {
      final extra = m.anomalyFlags.length > 1
          ? ' plus ${m.anomalyFlags.length - 1} more flag(s) - see Automated Observations below'
          : ' - see Automated Observations below for the exact threshold';
      return 'Right now the clearest thing to watch is: ${m.anomalyFlags.first}$extra.';
    }
    if (m.stabilityBand != StabilityBand.stable) {
      return 'Sway is a bit elevated (${m.stabilityMagnitude.toStringAsFixed(1)}°) without tripping an anomaly '
          'flag yet - worth keeping an eye on over the next session.';
    }
    return 'Nothing stands out - stability, impact, and pressure distribution are all within the stable band '
        'right now. Just keep the session running to build trend history on the Trends tab.';
  }

  String _mlpiAnswer(ProcessedBiomechanicsMetrics m) {
    return 'Your MLPI (medial-lateral pressure index) is ${m.mlpi.toStringAsFixed(1)} - it measures the imbalance '
        'between your inner and outer forefoot pressure. Higher values mean more lopsided loading side-to-side; '
        'it feeds directly into the ankle-instability check (>8° corrected roll with lateral-dominant pressure).';
  }

  String _anomalyAnswer(ProcessedBiomechanicsMetrics m) {
    if (m.anomalyFlags.isEmpty) {
      return 'No anomalies in the current rolling buffer (last ${m.bufferLength} samples) - everything is within '
          'its published threshold.';
    }
    final list = m.anomalyFlags.map((f) => '• $f').join('\n');
    return 'Active flags right now:\n$list\n\nEach one traces to an explicit threshold, not a prediction - see '
        '"Why These Alerts Fire" below for the exact numbers.';
  }

  String _cadenceAnswer(ProcessedBiomechanicsMetrics m) {
    return 'Cadence is ${m.cadenceSpm.toStringAsFixed(0)} steps/min right now, with a '
        '${m.stancePct}:${m.swingPct} stance-to-swing ratio in the ${m.gaitPhase.label.toLowerCase()} phase.';
  }

  String _generalAnswer() {
    return "I can answer questions about your stability score, MLPI, cadence, or any active anomaly flags - try "
        'one of the suggested questions above, or ask about a specific metric on this screen.';
  }
}
