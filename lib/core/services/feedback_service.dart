import 'dart:async';

import 'audio_service.dart';
import 'haptics_service.dart';

enum FeedbackConfettiStyle {
  none,
  streakBurst,
  levelUp,
}

class FeedbackCue {
  const FeedbackCue({
    this.scalePulse = false,
    this.buttonGlow = false,
    this.cardPulse = false,
    this.showXpFloat = false,
    this.progressGlow = false,
    this.confettiStyle = FeedbackConfettiStyle.none,
  });

  final bool scalePulse;
  final bool buttonGlow;
  final bool cardPulse;
  final bool showXpFloat;
  final bool progressGlow;
  final FeedbackConfettiStyle confettiStyle;
}

class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  FeedbackCue moodTap() {
    unawaited(HapticsService.instance.selectionClick());
    unawaited(AudioService.instance.playTap());

    return const FeedbackCue(scalePulse: true);
  }

  FeedbackCue submitAction() {
    unawaited(HapticsService.instance.mediumImpact());
    unawaited(AudioService.instance.playTap());

    return const FeedbackCue(
      buttonGlow: true,
      cardPulse: true,
    );
  }

  FeedbackCue streakMilestone() {
    unawaited(HapticsService.instance.mediumImpact());
    unawaited(AudioService.instance.playTap());

    return const FeedbackCue(
      cardPulse: true,
      showXpFloat: true,
      confettiStyle: FeedbackConfettiStyle.streakBurst,
    );
  }

  FeedbackCue levelUp() {
    unawaited(HapticsService.instance.heavyImpact());
    unawaited(AudioService.instance.playTap());

    return const FeedbackCue(
      cardPulse: true,
      showXpFloat: true,
      progressGlow: true,
      confettiStyle: FeedbackConfettiStyle.levelUp,
    );
  }

  FeedbackCue checkInSuccess() {
    unawaited(HapticsService.instance.lightImpact());
    unawaited(AudioService.instance.playTap());

    return const FeedbackCue(
      cardPulse: true,
      confettiStyle: FeedbackConfettiStyle.streakBurst,
    );
  }
}
