import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user/device settings - the Flutter analog of the
/// `localStorage` keys `useSensorData.ts` and `MainDashboard.tsx` read/wrote
/// in the web app (WS endpoint, relay endpoint, session/trial metadata,
/// upload endpoint + token).
///
/// Kept as a thin wrapper around [SharedPreferences] rather than routed
/// through Riverpod's async init dance everywhere it's used - callers await
/// [init] once at startup (see `main.dart`).
class SettingsRepository {
  static const _wsUrlKey = 'gaitguard.ws_endpoint';
  static const _relayUrlKey = 'gaitguard.ws_relay_endpoint';
  static const _uploadUrlKey = 'gaitguard.upload_endpoint';
  static const _uploadTokenKey = 'gaitguard.upload_token';
  static const _sessionIdKey = 'gaitguard.session_id';
  static const _trialIdKey = 'gaitguard.trial_id';
  static const _deviceOrientationDismissedKey = 'gaitguard.device_orientation_dismissed';

  static const defaultWsUrl = 'ws://192.168.4.1:81';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get wsUrl => _prefs.getString(_wsUrlKey) ?? defaultWsUrl;
  Future<void> setWsUrl(String value) => _prefs.setString(_wsUrlKey, value);

  String get relayUrl => _prefs.getString(_relayUrlKey) ?? '';
  Future<void> setRelayUrl(String value) => _prefs.setString(_relayUrlKey, value);

  String get uploadUrl => _prefs.getString(_uploadUrlKey) ?? '';
  Future<void> setUploadUrl(String value) => _prefs.setString(_uploadUrlKey, value);

  String get uploadToken => _prefs.getString(_uploadTokenKey) ?? '';
  Future<void> setUploadToken(String value) => _prefs.setString(_uploadTokenKey, value);

  String get sessionId {
    final stored = _prefs.getString(_sessionIdKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return 'session-$today';
  }

  Future<void> setSessionId(String value) => _prefs.setString(_sessionIdKey, value);

  String get trialId => _prefs.getString(_trialIdKey) ?? 'trial-001';
  Future<void> setTrialId(String value) => _prefs.setString(_trialIdKey, value);

  /// Whether the first-run "Live Sensor vs Simulation" orientation card on
  /// the Device screen has been dismissed. Lightweight one-flag onboarding -
  /// see `CONNECTIVITY_PLAN.md` for why this app deliberately doesn't have a
  /// full multi-step setup wizard.
  bool get deviceOrientationDismissed => _prefs.getBool(_deviceOrientationDismissedKey) ?? false;
  Future<void> dismissDeviceOrientation() => _prefs.setBool(_deviceOrientationDismissedKey, true);
}
