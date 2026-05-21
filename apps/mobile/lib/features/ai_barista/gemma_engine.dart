import 'package:flutter_gemma/flutter_gemma.dart';

/// Lifecycle of the on-device model, surfaced to the UI.
enum GemmaStatus {
  /// Not downloaded / not enabled yet — the offline keyword fallback is in use.
  notInstalled,

  /// Download or initialisation in progress.
  downloading,

  /// Model loaded; replies come from Gemma.
  ready,

  /// This device/emulator can't run the model (e.g. iOS Simulator). We stay on
  /// the keyword fallback — the feature still works, just without the LLM.
  unsupported,
}

/// Thin wrapper over `flutter_gemma` (0.12.6 Modern API).
///
/// Everything is wrapped so a failure to download or initialise never crashes
/// the app — the caller flips to [GemmaStatus.unsupported] and the Barista keeps
/// working via the deterministic keyword recommender. On-device LLM inference is
/// only reliable on physical devices; emulators/simulators usually fall back.
class GemmaEngine {
  InferenceModel? _model;
  InferenceChat? _chat;
  String _systemPreamble = '';
  bool _primed = false;

  bool get isReady => _chat != null;

  /// Download (idempotent — skips if cached), load the model on the CPU backend,
  /// and open a chat. [onProgress] reports 0.0–1.0. Throws on any failure; the
  /// caller is expected to treat a throw as "unsupported on this target".
  Future<void> ensureReady({
    required String modelUrl,
    String? hfToken,
    required String systemInstruction,
    required void Function(double progress) onProgress,
  }) async {
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
    )
        .fromNetwork(modelUrl, token: hfToken)
        .withProgress((int p) => onProgress(p / 100.0))
        .install();

    // CPU backend is the only one that has any chance on emulators/simulators;
    // on physical devices it's slower than GPU but always available.
    _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.cpu,
    );
    _chat = await _model!.createChat(
      temperature: 0.7,
      topK: 40,
      modelType: ModelType.gemmaIt,
    );
    _systemPreamble = systemInstruction;
    _primed = false;
  }

  /// Stream the model's reply token-by-token. The grounding preamble (persona +
  /// menu catalog) is folded into the first turn; later turns rely on the chat's
  /// retained history. 0.12.6's `createChat` has no system-role parameter, so we
  /// prepend it as the opening user message.
  Stream<String> send(String prompt) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('GemmaEngine.send called before ensureReady');
    }
    final text = _primed ? prompt : '$_systemPreamble\n\nCustomer: $prompt\nBarista:';
    _primed = true;
    await chat.addQueryChunk(Message.text(text: text, isUser: true));
    await for (final ModelResponse r in chat.generateChatResponseAsync()) {
      if (r is TextResponse) yield r.token;
    }
  }

  Future<void> dispose() async {
    try {
      await _model?.close();
    } catch (_) {
      // Closing a half-initialised model can throw; nothing useful to do.
    }
    _model = null;
    _chat = null;
    _primed = false;
  }
}
