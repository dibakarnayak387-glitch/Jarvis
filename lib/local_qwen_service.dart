import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class LocalQwenService {
  LlamaController? _controller;

  bool get isLoaded => _controller != null;

  Future<bool> loadModel() async {
    if (_controller != null) {
      return await _controller!.isModelLoaded();
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) {
      return false;
    }

    final path = result.files.single.path!;
    final controller = LlamaController();

    try {
      await controller.loadModel(
        modelPath: path,
        threads: 2,
        contextSize: 1024,
        gpuLayers: 0,
      );
      _controller = controller;
      return true;
    } catch (e) {
      debugPrint('Local Qwen load error: $e');
      await controller.dispose();
      rethrow;
    }
  }

  Future<String?> answer(String prompt) async {
    try {
      if (_controller == null) {
        final loaded = await loadModel();
        if (!loaded) return null;
      }

      final output = StringBuffer();

      await for (final token in _controller!.generateChat(
        messages: [
          ChatMessage(
            role: 'system',
            content: 'You are JARVIS, a helpful offline AI assistant. '
                'Answer clearly and concisely.',
          ),
          ChatMessage(role: 'user', content: prompt),
        ],
        template: 'qwen',
        maxTokens: 160,
        temperature: 0.6,
      )) {
        output.write(token);
      }

      final reply = output.toString().trim();
      return reply.isEmpty ? null : reply;
    } catch (e) {
      debugPrint('Local Qwen generation error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
  }
}
