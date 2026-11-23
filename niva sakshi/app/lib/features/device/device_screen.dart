import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/health_layout.dart';
import '../../shared/csv_share.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';

String? _validateWsUrl(String value, {required bool required}) {
  if (value.trim().isEmpty) return required ? 'Enter an endpoint' : null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Enter a valid endpoint';
  }
  if (uri.scheme != 'ws' && uri.scheme != 'wss') return 'Use ws:// or wss://';
  return null;
}

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});
  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  late final TextEditingController _endpoint;
  @override
  void initState() {
    super.initState();
    _endpoint =
        TextEditingController(text: ref.read(settingsRepositoryProvider).wsUrl);
  }

  bool _bluetooth = true;
  String? _error;
  bool _exporting = false;
  @override
  void dispose() {
    _endpoint.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await shareCsv(ref.read(telemetryRepositoryProvider).exportCsv(),
          'niva-sakshi-telemetry', 'Niva Sakshi telemetry');
    } catch (_) {
      _message('Could not export. Your samples are still saved.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Clear dataset?'),
                content: const Text(
                    'This permanently deletes the telemetry samples on this device.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'))
                ]));
    if (confirmed == true && mounted) {
      try {
        await ref.read(telemetryControllerProvider.notifier).clearDataset();
      } catch (_) {
        _message('Could not clear the dataset. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(telemetryControllerProvider);
    final control = ref.read(telemetryControllerProvider.notifier);
    return HealthPage(children: [
      HealthHeader(
          title: 'Device',
          subtitle: 'Your insole connection',
          trailing: IconButton(
              tooltip: 'Connection help',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => openHealthDetails(
                  context,
                  'Connect and prepare',
                  const Text(
                      'Connect over Bluetooth or Wi-Fi, then tare with nothing pressing on the insole. Wait for the instrument to report valid before using readings. Bluetooth requires a supported browser or a phone build.')))),
      RoundedCard(
          radius: 22,
          child: Row(children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.sensors_rounded,
                    color: AppColors.brand, size: 28)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Niva Insole',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      state.isDemo
                          ? 'Demo walk · simulated, not an insole'
                          : state.isConnecting
                              ? 'Connecting…'
                              : state.isConnected
                                  ? (state.isMeasurementValid
                                      ? 'Connected · valid'
                                      : 'Connected · tare needed')
                                  : 'Not connected',
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
          ])),
      if (kIsWeb)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
                'In a browser, Bluetooth needs Chrome or Edge and has not yet '
                'been tried with the insole. Secure (https) pages block plain '
                'ws:// Wi-Fi links. Run insole sessions in the Android app.',
                style: Theme.of(context).textTheme.bodySmall)),
      const HealthSection('Connection'),
      if (!state.isConnected)
        SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.bluetooth_rounded),
                  label: Text('Bluetooth')),
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.wifi_rounded),
                  label: Text('Wi-Fi'))
            ],
            selected: {
              _bluetooth
            },
            showSelectedIcon: false,
            onSelectionChanged: state.isConnected || state.isConnecting
                ? null
                : (v) => setState(() => _bluetooth = v.first)),
      const SizedBox(height: 12),
      RoundedCard(
          radius: 20,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!_bluetooth && !state.isConnected) ...[
              TextField(
                  controller: _endpoint,
                  enabled: !state.isConnected && !state.isConnecting,
                  decoration: InputDecoration(
                      labelText: 'Wi-Fi endpoint',
                      hintText: 'ws://192.168.4.1:81',
                      errorText: _error)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
                onPressed: state.isConnecting
                    ? null
                    : () async {
                        if (state.isDemo) {
                          control.stopDemo();
                          return;
                        }
                        if (state.isConnected) {
                          control.disconnectLive();
                          return;
                        }
                        if (_bluetooth) {
                          control.connectBle();
                          return;
                        }
                        final error =
                            _validateWsUrl(_endpoint.text, required: true);
                        setState(() => _error = error);
                        if (error != null) return;
                        try {
                          await ref
                              .read(settingsRepositoryProvider)
                              .setWsUrl(_endpoint.text.trim());
                          if (mounted) control.connectLive();
                        } catch (_) {
                          _message('Could not save the endpoint. Try again.');
                        }
                      },
                icon: Icon(state.isConnected
                    ? Icons.link_off_rounded
                    : _bluetooth
                        ? Icons.bluetooth_searching_rounded
                        : Icons.link_rounded),
                label: Text(state.isConnecting
                    ? 'Connecting…'
                    : state.isDemo
                        ? 'Stop demo'
                        : state.isConnected
                            ? 'Disconnect'
                            : _bluetooth
                                ? 'Find Niva Insole'
                                : 'Connect')),
            if (state.isConnected && !state.isDemo) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await control.tareLive();
                    } catch (_) {
                      _message(
                          'Could not tare. Check the connection and try again.');
                    }
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Tare unloaded insole')),
            ],
            if (state.connectionError != null) ...[
              const SizedBox(height: 10),
              Text(state.connectionError!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.danger)),
              TextButton(
                  onPressed: () =>
                      _bluetooth ? control.connectBle() : control.connectLive(),
                  child: const Text('Retry now')),
            ],
          ])),
      const HealthSection('Manage'),
      RoundedCard(
          radius: 20,
          padding: EdgeInsets.zero,
          child: Column(children: [
            HealthRow(
                title: 'Session & connection settings',
                subtitle: 'Session ID, trial ID and relay',
                icon: Icons.tune_rounded,
                onTap: () => _settings(context)),
            const Divider(height: 1, indent: 62),
            HealthRow(
                title: 'Export telemetry',
                subtitle: '${state.datasetCount} samples saved',
                icon: Icons.ios_share_rounded,
                onTap: _exporting
                    ? null
                    : () => openHealthDetails(
                        context,
                        'Telemetry dataset',
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  '${state.datasetCount} samples saved on this device.'),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _export();
                                  },
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: const Text('Export CSV')),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _clear();
                                  },
                                  child: const Text('Clear telemetry',
                                      style:
                                          TextStyle(color: AppColors.danger))),
                            ])),
                trailing: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null),
            const Divider(height: 1, indent: 62),
            HealthRow(
                title: 'Upload dataset',
                icon: Icons.cloud_upload_outlined,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const _UploadScreen()))),
          ])),
    ]);
  }

  void _settings(BuildContext context) => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => const _SessionSettingsScreen()));
}

class _SessionSettingsScreen extends ConsumerStatefulWidget {
  const _SessionSettingsScreen();
  @override
  ConsumerState<_SessionSettingsScreen> createState() =>
      _SessionSettingsState();
}

class _SessionSettingsState extends ConsumerState<_SessionSettingsScreen> {
  late final _session = TextEditingController(
      text: ref.read(settingsRepositoryProvider).sessionId);
  late final _trial =
      TextEditingController(text: ref.read(settingsRepositoryProvider).trialId);
  late final _relay = TextEditingController(
      text: ref.read(settingsRepositoryProvider).relayUrl);
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _session.dispose();
    _trial.dispose();
    _relay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Session settings')),
      body: HealthPage(children: [
        TextField(
            controller: _session,
            decoration: const InputDecoration(labelText: 'Session ID')),
        const SizedBox(height: 14),
        TextField(
            controller: _trial,
            decoration: const InputDecoration(labelText: 'Trial ID')),
        const SizedBox(height: 14),
        TextField(
            controller: _relay,
            decoration: InputDecoration(
                labelText: 'Relay endpoint (optional)', errorText: _error)),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    final error = _validateWsUrl(_relay.text, required: false);
                    setState(() => _error = error);
                    if (error != null) return;
                    setState(() => _saving = true);
                    try {
                      final settings = ref.read(settingsRepositoryProvider);
                      await settings.setSessionId(_session.text.trim());
                      await settings.setTrialId(_trial.text.trim());
                      await settings.setRelayUrl(_relay.text.trim());
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not save settings.')));
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Text(_saving ? 'Saving…' : 'Save settings')),
      ]));
}

class _UploadScreen extends ConsumerStatefulWidget {
  const _UploadScreen();
  @override
  ConsumerState<_UploadScreen> createState() => _UploadState();
}

class _UploadState extends ConsumerState<_UploadScreen> {
  late final _url = TextEditingController(
      text: ref.read(settingsRepositoryProvider).uploadUrl);
  late final _token = TextEditingController(
      text: ref.read(settingsRepositoryProvider).uploadToken);
  bool _uploading = false;
  String? _message;
  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Upload dataset')),
      body: HealthPage(children: [
        TextField(
            controller: _url,
            decoration: const InputDecoration(labelText: 'Upload endpoint')),
        const SizedBox(height: 14),
        TextField(
            controller: _token,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Bearer token (optional)')),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: _uploading
                ? null
                : () async {
                    setState(() {
                      _uploading = true;
                      _message = null;
                    });
                    try {
                      final settings = ref.read(settingsRepositoryProvider);
                      final repository = ref.read(telemetryRepositoryProvider);
                      final upload = ref.read(researchUploadServiceProvider);
                      await settings.setUploadUrl(_url.text.trim());
                      await settings.setUploadToken(_token.text);
                      final result = await upload.uploadCsv(
                          csvContent: repository.exportCsv(),
                          sampleCount: repository.sampleCount);
                      if (mounted) setState(() => _message = result.message);
                    } catch (_) {
                      if (mounted) {
                        setState(() => _message =
                            'Upload failed. Samples remain saved on this device.');
                      }
                    } finally {
                      if (mounted) setState(() => _uploading = false);
                    }
                  },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(_uploading ? 'Uploading…' : 'Upload dataset')),
        if (_message != null)
          Padding(
              padding: const EdgeInsets.only(top: 16), child: Text(_message!)),
      ]));
}
