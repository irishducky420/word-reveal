import 'package:flutter/services.dart';

/// Game audio/feedback abstraction.
///
/// Assumption: no licensed sound assets exist yet, so the default
/// implementation uses platform haptics/system sounds (zero assets, real
/// feedback). Swapping in `just_audio` with real files later means
/// implementing this interface in one new class and changing one provider.
abstract class AudioService {
  Future<void> wordFound();
  Future<void> invalidSelection();
  Future<void> puzzleCompleted();
  Future<void> imageCompleted();
  Future<void> hintUsed();
}

class SystemFeedbackAudioService implements AudioService {
  @override
  Future<void> wordFound() => HapticFeedback.lightImpact();

  @override
  Future<void> invalidSelection() => HapticFeedback.vibrate();

  @override
  Future<void> puzzleCompleted() => HapticFeedback.mediumImpact();

  @override
  Future<void> imageCompleted() => HapticFeedback.heavyImpact();

  @override
  Future<void> hintUsed() => HapticFeedback.selectionClick();
}
