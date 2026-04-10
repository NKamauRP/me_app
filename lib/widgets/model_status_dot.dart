import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class ModelStatusDot extends StatelessWidget {
  const ModelStatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AiModelVariant>(
      future: AiService.instance.getActiveVariant(),
      builder: (context, variantSnap) {
        if (!variantSnap.hasData) return const SizedBox.shrink();
        
        return FutureBuilder<bool>(
          future: AiService.instance.isModelDownloaded(variantSnap.data!),
          builder: (context, snap) {
            final downloaded = snap.data ?? false;
            final color = downloaded ? Colors.green : Colors.amber;
            final tooltip = downloaded
                ? 'AI ready'
                : 'AI model not downloaded — tap to download in Settings';
            return Tooltip(
              message: tooltip,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
