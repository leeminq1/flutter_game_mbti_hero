/// AdMob 관리자 (현재는 Mock 구현)
/// 나중에 google_mobile_ads 패키지와 연동
class AdManager {
  // 싱글톤
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 초기화
  Future<void> init() async {
    // TODO: 실제 AdMob 초기화
    // await MobileAds.instance.initialize();
    _isInitialized = true;
  }

  /// 보상형 광고 표시 (캐릭터 해금용)
  /// 반환값: 광고 시청 완료 여부
  Future<bool> showRewardedAd() async {
    // TODO: 실제 보상형 광고 표시
    // 현재는 Mock: 항상 성공으로 처리
    await Future.delayed(const Duration(milliseconds: 500)); // 로딩 시뮬레이션
    return true;
  }

  /// 전면 광고 표시 (한판 더 용)
  Future<void> showInterstitialAd() async {
    // TODO: 실제 전면 광고 표시
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
