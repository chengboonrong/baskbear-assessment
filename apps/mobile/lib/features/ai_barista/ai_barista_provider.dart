import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/env.dart';
import '../../core/weather/weather_service.dart';
import '../../data/models/ai_chat.dart';
import '../../data/models/menu_item.dart';
import '../../data/repositories/menu_repository.dart';
import 'gemma_engine.dart';
import 'mood.dart';

const _welcome =
    "Hi! I'm your Baskbear barista. Tell me what you're in the mood for — "
    "iced or hot, sweet, strong, dairy-free — and I'll suggest something.";

String _systemInstruction(List<MenuItemDto> menu) =>
    "You are Baskbear's friendly coffee barista. Recommend drinks ONLY from the "
    "menu below — never invent items. Keep replies to 2–3 short sentences. When "
    "you suggest a drink, wrap its EXACT name in double square brackets, e.g. "
    "[[Iced Latte]]. Be warm and concise.\n\nMENU:\n${buildMenuCatalog(menu)}";

// --- Barista chat state -------------------------------------------------------

class BaristaState {
  const BaristaState({
    required this.messages,
    this.sending = false,
    this.gemmaStatus = GemmaStatus.notInstalled,
    this.downloadProgress = 0,
    this.notice,
    this.mood,
  });

  final List<AiChatMessage> messages;
  final bool sending;
  final GemmaStatus gemmaStatus;
  final double downloadProgress;
  final String? notice;

  /// Currently-selected mood chip, or null. Persists across [copyWith] (which
  /// otherwise resets nullable fields) via the [_keep] sentinel.
  final Mood? mood;

  static const Object _keep = Object();

  BaristaState copyWith({
    List<AiChatMessage>? messages,
    bool? sending,
    GemmaStatus? gemmaStatus,
    double? downloadProgress,
    String? notice,
    Object? mood = _keep,
  }) =>
      BaristaState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        gemmaStatus: gemmaStatus ?? this.gemmaStatus,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        notice: notice,
        mood: identical(mood, _keep) ? this.mood : mood as Mood?,
      );
}

class BaristaController extends Notifier<BaristaState> {
  GemmaEngine get _engine => ref.read(gemmaEngineProvider);

  @override
  BaristaState build() => const BaristaState(
        messages: [AiChatMessage(role: AiRole.barista, text: _welcome)],
      );

  Future<List<MenuItemDto>> _menu() async {
    try {
      return await ref.read(menuListProvider.future);
    } catch (_) {
      return const [];
    }
  }

  void _append(AiChatMessage m) =>
      state = state.copyWith(messages: [...state.messages, m]);

  /// Download + initialise the on-device model. Any failure (the common case on
  /// the iOS Simulator) leaves us on the keyword fallback — the chat still works.
  Future<void> enableGemma() async {
    if (state.gemmaStatus == GemmaStatus.downloading ||
        state.gemmaStatus == GemmaStatus.ready) {
      return;
    }
    final url = AppEnv.gemmaModelUrl;
    if (url == null) {
      state = state.copyWith(
        gemmaStatus: GemmaStatus.unsupported,
        notice: 'Set GEMMA_MODEL_URL in .env to enable the on-device model. '
            'Using offline suggestions for now.',
      );
      return;
    }
    state = state.copyWith(
        gemmaStatus: GemmaStatus.downloading, downloadProgress: 0, notice: null);
    try {
      final menu = await _menu();
      await _engine.ensureReady(
        modelUrl: url,
        hfToken: AppEnv.huggingFaceToken,
        systemInstruction: _systemInstruction(menu),
        onProgress: (p) =>
            state = state.copyWith(downloadProgress: p, gemmaStatus: GemmaStatus.downloading),
      );
      state = state.copyWith(
          gemmaStatus: GemmaStatus.ready, notice: 'On-device AI ready.');
    } catch (e) {
      // Build/runtime failures here are expected on emulators/simulators.
      state = state.copyWith(
        gemmaStatus: GemmaStatus.unsupported,
        notice: "Couldn't start the on-device model on this device — "
            'using offline suggestions instead.',
      );
    }
  }

  /// Toggle a mood chip on/off.
  void setMood(Mood mood) =>
      state = state.copyWith(mood: state.mood == mood ? null : mood);

  Future<Weather?> _weather() async {
    try {
      return await ref.read(currentWeatherProvider.future);
    } catch (_) {
      return null;
    }
  }

  Future<void> send(String input) async {
    final text = input.trim();
    final mood = state.mood;
    // Allow a recommendation with no typing as long as a mood chip is picked.
    if ((text.isEmpty && mood == null) || state.sending) return;

    final shown = text.isEmpty
        ? "I'm feeling ${mood!.label.toLowerCase()} — any ideas?"
        : text;
    _append(AiChatMessage(role: AiRole.user, text: shown));
    state = state.copyWith(sending: true, notice: null);

    final menu = await _menu();
    final weather = await _weather();

    if (state.gemmaStatus == GemmaStatus.ready && _engine.isReady) {
      await _streamGemma(text, menu, mood, weather);
    } else {
      _replyFromKeywords(text, menu, mood, weather);
    }
    state = state.copyWith(sending: false);
  }

  void _replyFromKeywords(
      String text, List<MenuItemDto> menu, Mood? mood, Weather? weather) {
    final picks = recommendByKeywords(menu, composeQuery(text, mood, weather));
    _append(AiChatMessage(
      role: AiRole.barista,
      text: fallbackReply(picks, preface: naturalPreface(mood, weather)),
      recommendations: picks,
    ));
  }

  Future<void> _streamGemma(
      String text, List<MenuItemDto> menu, Mood? mood, Weather? weather) async {
    // Fold weather/mood context into the turn so Gemma factors it in.
    final ctx = llmContextLine(mood, weather);
    final prompt = ctx.isEmpty ? text : '$ctx\n$text';

    // Placeholder bubble we grow as tokens arrive.
    _append(const AiChatMessage(role: AiRole.barista, text: ''));
    final buffer = StringBuffer();
    try {
      await for (final token in _engine.send(prompt)) {
        buffer.write(token);
        _replaceLast(AiChatMessage(role: AiRole.barista, text: buffer.toString()));
      }
      final reply = buffer.toString();
      _replaceLast(AiChatMessage(
        role: AiRole.barista,
        text: reply.isEmpty ? fallbackReply(const []) : reply,
        recommendations: extractRecommendations(reply, menu),
      ));
    } catch (_) {
      // Inference died mid-stream — salvage with the keyword fallback.
      final picks = recommendByKeywords(menu, composeQuery(text, mood, weather));
      _replaceLast(AiChatMessage(
        role: AiRole.barista,
        text: fallbackReply(picks, preface: naturalPreface(mood, weather)),
        recommendations: picks,
      ));
    }
  }

  void _replaceLast(AiChatMessage m) {
    final msgs = [...state.messages];
    msgs[msgs.length - 1] = m;
    state = state.copyWith(messages: msgs);
  }
}

final gemmaEngineProvider = Provider<GemmaEngine>((ref) {
  final engine = GemmaEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final baristaControllerProvider =
    NotifierProvider<BaristaController, BaristaState>(BaristaController.new);

// --- Speech (on-device STT + TTS) --------------------------------------------

class SpeechState {
  const SpeechState({this.available = false, this.listening = false});
  final bool available;
  final bool listening;

  SpeechState copyWith({bool? available, bool? listening}) =>
      SpeechState(
        available: available ?? this.available,
        listening: listening ?? this.listening,
      );
}

class SpeechController extends Notifier<SpeechState> {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  @override
  SpeechState build() {
    Future.microtask(_init);
    ref.onDispose(() {
      _stt.cancel();
      _tts.stop();
    });
    return const SpeechState();
  }

  Future<void> _init() async {
    try {
      final ok = await _stt.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            state = state.copyWith(listening: false);
          }
        },
        onError: (_) => state = state.copyWith(listening: false),
      );
      state = state.copyWith(available: ok);
    } catch (_) {
      state = state.copyWith(available: false);
    }
  }

  /// Start dictation; [onText] receives the latest transcript as it updates.
  Future<void> startListening(void Function(String text) onText) async {
    if (!state.available || state.listening) return;
    state = state.copyWith(listening: true);
    await _stt.listen(onResult: (r) => onText(r.recognizedWords));
  }

  Future<void> stopListening() async {
    await _stt.stop();
    state = state.copyWith(listening: false);
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }
}

final speechControllerProvider =
    NotifierProvider<SpeechController, SpeechState>(SpeechController.new);
