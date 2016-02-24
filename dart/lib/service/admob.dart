library bacchus_diary.service.admob;

import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';

final Logger _logger = new Logger('AdMob');

class AdMob {
  static Completer<AdMob> _initialized;

  static Future<AdMob> initialize() async {
    if (_initialized == null) {
      _initialized = new Completer();
      final map = (await Settings).advertisement.admod;
      _initialized.complete(new AdMob(map));
    }
    return _initialized.future;
  }

  static showInterstitial(String timing) async {
    final admod = await initialize();
    if (admod.interstitialTimings.contains(timing)) {
      admod._invoke('showInterstitial');
    }
  }

  static get plugin => context['AdMob'];

  static position(String name) => plugin == null ? null : plugin['AD_POSITION'][name];

  final Map<String, Map<String, dynamic>> _src;
  AdMob(this._src) {
    _invoke('createBanner', {'adId': bannerId, 'position': position(bannerPos), 'autoShow': true});
    _invoke('prepareInterstitial', {'adId': interstitialId, 'autoShow': false});
  }

  _invoke(String name, [Map params = const {}]) {
    _logger.info(() => "Invoking ${name}: ${params}");
    plugin?.callMethod(name, new JsObject.jsify(params));
  }

  Map<String, String> get _banner => _src['banner'];
  String get bannerId => _banner['id'];
  String get bannerPos => _banner['position'];

  Map<String, dynamic> get _interstitial => _src['interstitial'];
  String get interstitialId => _interstitial['id'];
  List<String> get interstitialTimings => _interstitial['timings'];
}
