library bacchus_diary.service.admob;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';

final Logger _logger = new Logger('AdMob');

class AdMob {
  static Completer<AdMob> _initialized;
  static Future<AdMob> get _singleton => _initialized?.future;

  static Future<Null> initialize() async {
    if (_initialized == null) {
      _initialized = new Completer();
      final map = (await Settings).advertisement.admod;
      _initialized.complete(new AdMob(map));
    }
    await _initialized.future;
  }

  static get plugin => context['AdMob'];

  static position(String name) => plugin == null ? null : plugin['AD_POSITION'][name];

  static showInterstitial(String timing) async => (await _singleton)?._showInterstitial(timing);
  static showBanner() async => (await _singleton)?._showBanner();
  static hideBanner() async => (await _singleton)?._hideBanner();

  final Map<String, Map<String, dynamic>> _src;
  AdMob(this._src) {
    _invoke('setOptions', {'adSize': 'SMART_BANNER', 'position': position(bannerPos), 'overlap': false});
    _invoke('createBanner', {'adId': bannerId, 'autoShow': true});
    _invoke('prepareInterstitial', {'adId': interstitialId, 'autoShow': false});

    document.addEventListener('onAdDismiss', (event) {
      _logger.fine(() => "Advertisement Closed");
      if (_isInterstitialShown) {
        _isInterstitialShown = false;
        showBanner();
      }
    });
  }

  bool _isInterstitialShown = false;

  _showInterstitial(String timing) async {
    _logger.finest(() => "Checking interstitial: ${timing}");
    if (interstitialTimings.contains(timing)) {
      await _invoke('showInterstitial');
      _isInterstitialShown = true;
    }
  }

  _showBanner() => _invoke('showBanner');
  _hideBanner() => _invoke('hideBanner');

  Future<Null> _invoke(String name, [Map params = const {}]) {
    final result = new Completer();
    _logger.info(() => "Invoking ${name}: ${params}");
    plugin?.callMethod(name, [
      new JsObject.jsify(params),
      (success) {
        _logger.info(() => "Result of ${name}: ${success}");
        result.complete();
      },
      (error) {
        _logger.warning(() => "Error on ${name}: ${error}");
        result.completeError(error);
      }
    ]);
    return result.future;
  }

  Map<String, String> get _banner => _src['banner'];
  String get bannerId => _banner['id'];
  String get bannerPos => _banner['position'];

  Map<String, dynamic> get _interstitial => _src['interstitial'];
  String get interstitialId => _interstitial['id'];
  List<String> get interstitialTimings => _interstitial['timings'];
}
