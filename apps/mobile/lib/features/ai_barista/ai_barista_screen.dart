import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/weather/weather_service.dart';
import '../../data/models/ai_chat.dart';
import '../../data/models/menu_item.dart';
import '../../shared/widgets/lotties.dart';
import 'ai_barista_provider.dart';
import 'gemma_engine.dart';
import 'mood.dart';

class AiBaristaScreen extends ConsumerStatefulWidget {
  const AiBaristaScreen({super.key});
  @override
  ConsumerState<AiBaristaScreen> createState() => _AiBaristaScreenState();
}

class _AiBaristaScreenState extends ConsumerState<AiBaristaScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submit() {
    final text = _input.text;
    final mood = ref.read(baristaControllerProvider).mood;
    if (text.trim().isEmpty && mood == null) return;
    _input.clear();
    ref.read(baristaControllerProvider.notifier).send(text);
  }

  Future<void> _toggleMic() async {
    final speech = ref.read(speechControllerProvider.notifier);
    final listening = ref.read(speechControllerProvider).listening;
    if (listening) {
      await speech.stopListening();
    } else {
      await speech.startListening((t) {
        _input.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll as the transcript grows.
    ref.listen(baristaControllerProvider, (_, __) => _scrollToEnd());

    final state = ref.watch(baristaControllerProvider);
    final speech = ref.watch(speechControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Barista'),
        actions: [
          if (state.gemmaStatus == GemmaStatus.ready)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Chip(
                  avatar: Icon(Icons.bolt, size: 16),
                  label: Text('On-device'),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _GemmaBanner(state: state),
          const _WeatherStrip(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              itemBuilder: (_, i) => _Bubble(message: state.messages[i]),
            ),
          ),
          if (state.sending)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LottieLoader(size: 28, center: false),
                  SizedBox(width: 8),
                  Text('Barista is thinking…',
                      style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                ],
              ),
            ),
          _MoodChips(selected: state.mood),
          _InputBar(
            controller: _input,
            sending: state.sending,
            micAvailable: speech.available,
            listening: speech.listening,
            onMic: _toggleMic,
            onSend: _submit,
          ),
        ],
      ),
    );
  }
}

class _GemmaBanner extends ConsumerWidget {
  const _GemmaBanner({required this.state});
  final BaristaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    switch (state.gemmaStatus) {
      case GemmaStatus.notInstalled:
        return Material(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Enable the on-device Gemma model for smarter replies. '
                    'Until then I use quick offline suggestions.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(baristaControllerProvider.notifier).enableGemma(),
                  child: const Text('Enable AI'),
                ),
              ],
            ),
          ),
        );
      case GemmaStatus.downloading:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Downloading model… ${(state.downloadProgress * 100).round()}%',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: state.downloadProgress == 0 ? null : state.downloadProgress,
              ),
            ],
          ),
        );
      case GemmaStatus.unsupported:
        return Material(
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.notice ?? 'Using offline suggestions.',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      case GemmaStatus.ready:
        return const SizedBox.shrink();
    }
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});
  final AiChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == AiRole.user;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: TextStyle(
                      color: isUser ? scheme.onPrimary : scheme.onSurface),
                ),
              if (!isUser && message.text.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => ref
                        .read(speechControllerProvider.notifier)
                        .speak(message.text),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.volume_up_outlined, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final item in message.recommendations) _RecCard(item: item),
      ],
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.item});
  final MenuItemDto item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const BearAvatar(size: 44),
        title: Text(item.name),
        subtitle: Text(formatMoney(item.priceMinor, item.currencyCode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/menu/${item.id}'),
      ),
    );
  }
}

class _WeatherStrip extends ConsumerWidget {
  const _WeatherStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(currentWeatherProvider).asData?.value;
    if (weather == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        '${weather.emoji}  ${weather.label} — I\'ll factor that in',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _MoodChips extends ConsumerWidget {
  const _MoodChips({required this.selected});
  final Mood? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final mood in Mood.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${mood.emoji} ${mood.label}'),
                selected: selected == mood,
                onSelected: (_) =>
                    ref.read(baristaControllerProvider.notifier).setMood(mood),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.micAvailable,
    required this.listening,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool micAvailable;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask for a recommendation…',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            if (micAvailable)
              IconButton(
                tooltip: listening ? 'Stop' : 'Speak',
                onPressed: onMic,
                icon: Icon(listening ? Icons.mic : Icons.mic_none),
                color: listening ? Theme.of(context).colorScheme.primary : null,
              ),
            IconButton(
              tooltip: 'Send',
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
