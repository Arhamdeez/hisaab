/// Splash animation constants.
abstract final class SplashTiming {
  static const logoSize = 88.0;

  /// Pure black beat before the logo fades in.
  static const enterDelay = Duration(milliseconds: 140);

  /// Logo fade-in — slow and soft before hold / drop / bubble.
  static const enterFade = Duration(milliseconds: 820);

  /// Logo rests at full size before drop + bubble.
  static const introHold = Duration(milliseconds: 680);
}
