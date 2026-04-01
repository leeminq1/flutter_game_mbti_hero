import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdPlacement {
  reviveContinue,
  characterUnlock,
  genericReward,
  genericInterstitial,
}

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  bool _isInitialized = false;
  bool _interstitialAdInProgress = false;
  
  // 구글 정책 및 기획에 맞게 '전면 광고 (InterstitialAd)' 클래스 사용
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  final int maxFailedLoadAttempts = 3;

  bool get isInitialized => _isInitialized;
  // 기존 코드 호환성을 위해 변수명 유지
  bool get isRewardedAdInProgress => _interstitialAdInProgress; 
  bool get isInterstitialAdInProgress => _interstitialAdInProgress;

  /// 개발자님이 올바르게 발급해주신 '전면 광고' 단위 ID (실제 출시용)
  static const String _realInterstitialAdUnitIdAndroid = 'ca-app-pub-9991463854626958/4308485713';
  
  /// 구글이 제공하는 테스트용 '전면 광고' ID (디버그 모드에서 자동 사용)
  static const String _testInterstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';

  Future<void> init() async {
    if (_isInitialized) return;
    await MobileAds.instance.initialize();
    _isInitialized = true;
    _createInterstitialAd(); // 캐싱을 위해 미리 로드
  }

  String get _interstitialAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) return _testInterstitialAdUnitIdAndroid;
      if (Platform.isIOS) return _testInterstitialAdUnitIdIOS;
    } else {
      if (Platform.isAndroid) return _realInterstitialAdUnitIdAndroid;
    }
    if (Platform.isAndroid) return _testInterstitialAdUnitIdAndroid;
    if (Platform.isIOS) return _testInterstitialAdUnitIdIOS;
    return '';
  }

  /// 전면 광고를 캐싱하여 로드
  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('[$AdManager] 전면 광고 로드 성공');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[$AdManager] 전면 광고 로드 실패: $error');
          _interstitialAd = null;
          _numInterstitialLoadAttempts += 1;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
             // 잠시 여유를 두고 재시도
            Future.delayed(const Duration(seconds: 2), _createInterstitialAd);
          }
        },
      ),
    );
  }

  // 외부 함수명은 호환성을 위해 showReviveRewardedAd 로 유지하지만, 내용은 전면광고 띄우기임
  Future<bool> showReviveRewardedAd() async {
    await _ensureInitialized();

    if (_interstitialAdInProgress) return false;

    // 광고가 아직 로드 안 되었다면 방어 로직 -> 로드가 안되면 그냥 무료로 살려줌(쾌적한 플레이)
    if (_interstitialAd == null) {
       _createInterstitialAd();
       await Future.delayed(const Duration(milliseconds: 500));
       if (_interstitialAd == null) {
         debugPrint('[$AdManager] 전면 광고 미로드 상태. 광고 없이 바로 부활시킵니다.');
         return true; // 로드 안되었을 때 유저가 화내지 않도록 쿨하게 그냥 살려줍니다.
       }
    }

    _interstitialAdInProgress = true;
    final completer = Completer<bool>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        debugPrint('[$AdManager] 전면 광고 화면 띄워짐');
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('[$AdManager] 전면 광고 닫힘 -> 바로 부활 처리');
        ad.dispose();
        _interstitialAd = null;
        _createInterstitialAd(); // 다음을 위해 미리 로드
        _interstitialAdInProgress = false;
        
        // 전면 광고는 끄면 무조건 조건 없이 부활시켜줍니다.
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('[$AdManager] 전면 광고 띄우기 실패: $error');
        ad.dispose();
        _interstitialAd = null;
        _createInterstitialAd();
        _interstitialAdInProgress = false;
        // 띄우기 실패했더라도 쿨하게 부활시켜줍니다.
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    _interstitialAd!.show();

    return completer.future; // 광고가 닫힐 때까지 비동기 대기
  }

  Future<void> showInterstitialAd({
    AdPlacement placement = AdPlacement.genericInterstitial,
  }) async {
    await showReviveRewardedAd();
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await init();
  }
}
