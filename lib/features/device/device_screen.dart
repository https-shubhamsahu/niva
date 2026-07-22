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
                  onSubmitted: (value) => settings.setWsUrl(value),
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Relay endpoint (optional, wss://)',
                  controller: _relayUrlController,
                  hint: 'wss://your-relay.example/ws',
                  onSubmitted: (value) => settings.setRelayUrl(value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          settings.setWsUrl(_wsUrlController.text);
                          settings.setRelayUrl(_relayUrlController.text);
                          if (state.isConnected) {
                            controller.disconnectLive();
                          } else {
                            controller.connectLive();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: state.isConnected ? AppColors.danger : AppColors.brand,
                        ),
                        icon: Icon(state.isConnected ? Icons.link_off_rounded : Icons.link_rounded),
                        label: Text(state.isConnected ? 'Disconnect' : 'Connect'),
                      ),
                    ),
                  ],
                ),
                if (state.connectionError != null) ...[
                  const SizedBox(height: 10),
                  Text(state.connectionError!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warning)),
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

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final bool obscureText;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.obscureText = false,
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
