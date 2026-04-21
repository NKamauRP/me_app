class ModelConfig {
  final String id;
  final String name;
  final String downloadUrl;
  final String format; // "gguf", "task", "litertlm", etc.
  final String engine; // "gemma", "llama_cpp" (future use)
  final String estimate;
  final int? expectedSize;

  const ModelConfig({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.format,
    required this.engine,
    required this.estimate,
    this.expectedSize,
  });
}

class ModelArtifact {
  final String id;
  final String name;
  final String format;
  final String localPath;
  final int sizeInBytes;

  const ModelArtifact({
    required this.id,
    required this.name,
    required this.format,
    required this.localPath,
    required this.sizeInBytes,
  });
}

class ModelRegistry {
  static const List<ModelConfig> models = [
    // ── NEW GGUF MODELS (Future llama.cpp) ──────────────────────────
    ModelConfig(
      id: 'qwen_0_5b_gguf',
      name: 'Qwen 0.5B (GGUF)',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2-0.5B-GGUF/resolve/main/qwen2-0_5b-q4_k_m.gguf',
      format: 'gguf',
      engine: 'llama_cpp',
      estimate: '~350 MB',
    ),
    
    // ── LEGACY MODELS (Current flutter_gemma) ───────────────────────
    ModelConfig(
      id: 'gemma_4_e2b',
      name: 'Gemma 4 E2B',
      downloadUrl: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      format: 'litertlm',
      engine: 'gemma',
      estimate: '~1.4 GB',
    ),
    ModelConfig(
      id: 'qwen3_0_6b',
      name: 'Qwen3 0.6B',
      downloadUrl: 'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_multi-prefill-seq_q8_ekv1280.task',
      format: 'task',
      engine: 'gemma',
      estimate: '~600 MB',
    ),
  ];

  static ModelConfig? getById(String id) {
    try {
      return models.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}
