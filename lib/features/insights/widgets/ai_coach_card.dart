import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/providers/telemetry_state.dart';
import '../../../core/services/ai_coach_service.dart';
import '../../../shared/widgets/rounded_card.dart';
import '../../../theme/app_theme.dart';

const _suggestedQuestions = [
  'Why is my stability low?',
  'What should I focus on today?',
  'Explain my MLPI score',
  'Any anomalies?',
];

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage(this.text, this.isUser);
}

/// Demo-ready "AI Coach" - chat-style Q&A that *feels* AI-powered (typing
/// delay, streaming reveal) but is entirely template-generated from data
/// already live in [TelemetryState] via [TemplatedAiCoachService]. No
/// network call, no API key, no latency/failure risk mid-demo. See that
/// service's doc comment for the intended swap-to-a-real-LLM seam.
class AiCoachCard extends StatefulWidget {
  final TelemetryState snapshot;
  const AiCoachCard({super.key, required this.snapshot});

  @override
  State<AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends State<AiCoachCard> {
  static const _service = TemplatedAiCoachService();
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _isThinking = false;
  String _streamedText = '';
  Timer? _streamTimer;

  @override
  void dispose() {
    _controller.dispose();
    _streamTimer?.cancel();
    super.dispose();
  }

  void _ask(String question) {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isThinking) return;
    HapticFeedback.selectionClick();
    setState(() {
      _messages.add(_ChatMessage(trimmed, true));
      _isThinking = true;
      _controller.clear();
    });

    // 400-800ms simulated "thinking" delay - long enough to read as
    // deliberate, short enough not to stall a live demo.
    final delayMs = 400 + Random().nextInt(400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      final answer = _service.answer(trimmed, widget.snapshot);
      setState(() {
        _isThinking = false;
        _messages.add(_ChatMessage(answer, false));
        _streamedText = '';
      });
      _streamAnswer(answer);
    });
  }

  void _streamAnswer(String fullText) {
    _streamTimer?.cancel();
    var shown = 0;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 14), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      shown += 2;
      setState(() => _streamedText = fullText.substring(0, min(shown, fullText.length)));
      if (shown >= fullText.length) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoundedCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text('AI COACH', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.brand)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Based on your live sensor data - generated from this app's own thresholds, not a black-box model.",
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: theme.textTheme.labelSmall?.color),
          ),
          const SizedBox(height: 14),
          if (_messages.isEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedQuestions.map((q) {
                return GestureDetector(
                  onTap: () => _ask(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBFD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      q,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.brand, fontSize: 13),
                    ),
                  ),
                );
              }).toList(),
            ),
          for (var i = 0; i < _messages.length; i++) ...[
            const SizedBox(height: 10),
            _ChatBubble(
              isUser: _messages[i].isUser,
              text: (!_messages[i].isUser && i == _messages.length - 1) ? _streamedText : _messages[i].text,
            ),
          ],
          if (_isThinking) ...[
            const SizedBox(height: 10),
            const _ThinkingBubble(),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: theme.textTheme.bodyMedium,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ask about your gait...',
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: _ask,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _ask(_controller.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  const _ChatBubble({required this.isUser, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brand : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(color: isUser ? Colors.white : null),
        ),
      ),
    );
  }
}

/// Three dots pulsing in sequence - the "typing" cue that sells the AI
/// feel while the templated answer is (deliberately) delayed.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_controller.value + i * 0.2) % 1.0;
                final scale = 0.6 + 0.4 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
