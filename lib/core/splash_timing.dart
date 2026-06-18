/// Splash animation constants.
abstract final class SplashTiming {
  static const logoSize = 88.0;

  /// Pure black beat before the logo fades in.
  static const enterDelay = Duration(milliseconds: 140);

  /// Logo fade-in — slow and soft before hold / drop / bubble.
  static const enterFade = Duration(milliseconds: 820);

  /// Logo rests at full size before drop + bubble.
  static const introHold = Duration(milliseconds: 680);

  /// Logo drop before the bubble reveal.
  static const dropDuration = Duration(milliseconds: 580);

  /// Circular bubble reveal.
  static const bubbleDuration = Duration(milliseconds: 850);

  /// Pause after the bubble reveal before the Home spotlight tour appears.
  static const postBubbleTourDelay = Duration(milliseconds: 650);
}
