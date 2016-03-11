library bacchus_diary.service.admob;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';

final _logger = new Logger('AdMob');

class AdMob {
  static Completer<_AdMob> _initialized;
  static Future<_AdMob> get _singleton => _initialized?.future;

  static Future<Null> initialize() async {
    if (_initialized == null) {
      _initialized = new Completer();
      final map = (await Settings).advertisement.admob;
      _initialized.complete(new _AdMob(map));
    }
    await _initialized.future;
  }

  static showInterstitial(String timing) async => (await _singleton)?.showInterstitial(timing);
  static showBanner() async => (await _singleton)?.showBanner();
  static hideBanner() async => (await _singleton)?.hideBanner();
}

class _AdMob {
  final Map<String, Map<String, dynamic>> _src;

  _AdMob(this._src) {
    if (isBarnnerAvailable) {
      _invoke('setOptions', {'adSize': 'SMART_BANNER', 'position': plugin['AD_POSITION'][bannerPos], 'overlap': false});
      _invoke('createBanner', {'adId': bannerId, 'autoShow': true});
    }
    if (isInterstitialAvailable) {
      _invoke('prepareInterstitial', {'adId': interstitialId, 'autoShow': false});
    }

    document.addEventListener('onAdDismiss', (event) {
      _logger.fine(() => "Advertisement Closed");
      if (_isInterstitialShown) {
        _isInterstitialShown = false;
        showBanner();
      }
    });
  }

  bool _isInterstitialShown = false;

  showInterstitial(String timing) async {
    if (isInterstitialAvailable) {
      _logger.finest(() => "Checking interstitial: ${timing}");
      if (interstitialTimings.contains(timing)) {
        await _invoke('showInterstitial');
        _isInterstitialShown = true;
      }
    }
  }

  showBanner() {
    if (isBarnnerAvailable) _invoke('showBanner');
  }

  hideBanner() {
    if (isBarnnerAvailable) _invoke('hideBanner');
  }

  void _invoke(String name, [Map params]) {
    _logger.info(() => "Invoking ${name}: ${params}");
    final args = params == null ? [] : [new JsObject.jsify(params)];
    plugin?.callMethod(name, args);
  }

  JsObject get plugin => context[_src['pluginName']];

  Map<String, String> get _banner => _src['banner'];
  String get bannerId => _banner['id'];
  String get bannerPos => _banner['position'];
  bool get isBarnnerAvailable => plugin != null && bannerId != null && bannerPos != null;

  Map<String, dynamic> get _interstitial => _src['interstitial'];
  String get interstitialId => _interstitial['id'];
  List<String> get interstitialTimings => _interstitial['timings'];
  bool get isInterstitialAvailable => plugin != null && interstitialId != null && interstitialTimings != null;
}
