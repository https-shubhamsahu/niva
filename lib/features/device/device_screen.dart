import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/widgets/rounded_card.dart';
import '../../theme/app_theme.dart';

/// "Device" tab - ESP32 connection settings, dataset export/upload, and
/// session metadata. Consolidates the WebSocket config section, dataset
/// controls, and session/trial/disease fields from `DeviceSettings.tsx`
/// and `MainDashboard.tsx`. The web app's pin-matrix / hardware-log /
/// troubleshooting-matrix reference sections were left out of the mobile
/// UI on purpose - they're firmware documentation, better served by the
/// README than by on-device screens - see BETTERMENTS.md.
/// Validates a WebSocket endpoint typed into the ESP32 card: non-empty (when
/// [required], i.e. the primary wsUrl field - the relay field is optional),
/// a parseable URI, and a `ws`/`wss` scheme. Catching this inline means a
/// clearly-malformed URL never reaches [Esp32SocketService.connect] at all,
/// saving a doomed connect attempt and its backoff cycle.
String? _validateWsUrl(String value, {required bool required}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return required ? 'Required' : null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
  if (uri.scheme != 'ws' && uri.scheme != 'wss') return 'Must start with ws:// or wss://';
  return null;
}

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  late final TextEditingController _wsUrlController;
  late final TextEditingController _relayUrlController;
  late final TextEditingController _sessionIdController;
  late final TextEditingController _trialIdController;
  late final TextEditingController _uploadUrlController;
  late final TextEditingController _uploadTokenController;

  bool _isUploading = false;
  String? _uploadMessage;
  String? _wsUrlError;
  String? _relayUrlError;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsRepositoryProvider);
    _wsUrlController = TextEditingController(text: settings.wsUrl);
    _relayUrlController = TextEditingController(text: settings.relayUrl);
    _sessionIdController = TextEditingController(text: settings.sessionId);
    _trialIdController = TextEditingController(text: settings.trialId);
    _uploadUrlController = TextEditingController(text: settings.uploadUrl);
    _uploadTokenController = TextEditingController(text: settings.uploadToken);
  }

  @override
  void dispose() {
    _wsUrlController.dispose();
    _relayUrlController.dispose();
    _sessionIdController.dispose();
    _trialIdController.dispose();
    _uploadUrlController.dispose();
    _uploadTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(telemetryControllerProvider);
    final controller = ref.read(telemetryControllerProvider.notifier);
    final settings = ref.read(settingsRepositoryProvider);
    final repository = ref.read(telemetryRepositoryProvider);
    final uploadService = ref.read(researchUploadServiceProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Device', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          RoundedCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ESP32 WEBSOCKET STREAM', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Endpoint (ws:// or wss://)',
                  controller: _wsUrlController,
                  hint: 'ws://192.168.4.1:81',
                  errorText: _wsUrlError,
                  onSubmitted: (value) {
                    final error = _validateWsUrl(value, required: true);
                    setState(() => _wsUrlError = error);
                    if (error == null) settings.setWsUrl(value);
                  },
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Relay endpoint (optional, wss://)',
                  controller: _relayUrlController,
                  hint: 'wss://your-relay.example/ws',
                  errorText: _relayUrlError,
                  onSubmitted: (value) {
                    final error = _validateWsUrl(value, required: false);
                    setState(() => _relayUrlError = error);
                    if (error == null) settings.setRelayUrl(value);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.isConnecting
                            ? null
                            : () {
                                if (state.isConnected) {
                                  controller.disconnectLive();
                                  return;
                                }
                                final wsError = _validateWsUrl(_wsUrlController.text, required: true);
                                final relayError = _validateWsUrl(_relayUrlController.text, required: false);
                                setState(() {
                                  _wsUrlError = wsError;
                                  _relayUrlError = relayError;
                                });
                                if (wsError != null || relayError != null) return;
                                settings.setWsUrl(_wsUrlController.text);
                                settings.setRelayUrl(_relayUrlController.text);
                                controller.connectLive();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: state.isConnected ? AppColors.danger : AppColors.brand,
                        ),
                        icon: state.isConnecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(state.isConnected ? Icons.link_off_rounded : Icons.link_rounded),
                        label: Text(
                          state.isConnecting ? 'Connecting...' : (state.isConnected ? 'Disconnect' : 'Connect'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.isConnected) ...[
                  const SizedBox(height: 10),
                  _ConnectionStatusRow(activeUrl: state.activeUrl, lastMessageAt: state.lastMessageAt),
                ],
                if (state.connectionError != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.connectionError!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.connectLive,
                        child: const Text('Retry now'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SESSION METADATA', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Session ID',
                  controller: _sessionIdController,
                  hint: 'session-2026-07-22',
                  onSubmitted: (value) => settings.setSessionId(value),
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Trial ID',
                  controller: _trialIdController,
                  hint: 'trial-001',
                  onSubmitted: (value) => settings.setTrialId(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESEARCH DATASET', style: theme.textTheme.labelSmall),
                const SizedBox(height: 10),
                Text(
                  '${state.datasetCount} samples stored on-device · ${state.datasetStatus}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await repository.exportCsvToFile();
                        await Share.shareXFiles([XFile(file.path)], text: 'GaitGuard Nexus dataset export');
                      },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Export CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await _confirmClear(context);
                        if (confirmed == true) {
                          await controller.clearDataset();
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RoundedCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BACKEND UPLOAD', style: theme.textTheme.labelSmall),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Upload endpoint',
                  controller: _uploadUrlController,
                  hint: 'https://your-api.example.com/upload',
                  onSubmitted: (value) => settings.setUploadUrl(value),
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Bearer token (optional)',
                  controller: _uploadTokenController,
                  hint: '',
                  onSubmitted: (value) => settings.setUploadToken(value),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () async {
                          settings.setUploadUrl(_uploadUrlController.text);
                          settings.setUploadToken(_uploadTokenController.text);
                          setState(() {
                            _isUploading = true;
                            _uploadMessage = null;
                          });
                          try {
                            final csv = repository.exportCsv();
                            final result = await uploadService.uploadCsv(
                              csvContent: csv,
                              sampleCount: repository.sampleCount,
                            );
                            setState(() => _uploadMessage = result.message);
                          } catch (e) {
                            setState(() => _uploadMessage = e.toString());
                          } finally {
                            setState(() => _isUploading = false);
                          }
                        },
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload dataset'),
                ),
                if (_uploadMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(_uploadMessage!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear dataset?'),
        content: const Text('This permanently deletes every sample stored on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Shows the currently-dialed endpoint and when data last arrived. Uses
/// absolute wall-clock time rather than a relative "Xs ago" label so this
/// stays pure data formatting - no periodic-rebuild timer needed on what's
/// otherwise a static settings screen.
class _ConnectionStatusRow extends StatelessWidget {
  final String activeUrl;
  final DateTime? lastMessageAt;

  const _ConnectionStatusRow({required this.activeUrl, required this.lastMessageAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.labelSmall?.color);
    final lastUpdateText = lastMessageAt == null ? 'No data yet' : 'Last update: ${_formatTime(lastMessageAt!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connected to $activeUrl', style: style),
        Text(lastUpdateText, style: style),
      ],
    );
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final bool obscureText;
  final String? errorText;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.obscureText = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          onTapOutside: (_) => onSubmitted(controller.text),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            isDense: true,
            filled: true,
            fillColor: theme.brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
