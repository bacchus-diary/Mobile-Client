library bacchus_diary.service.admod;

import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/settings.dart';

final Logger _logger = new Logger('AdMod');

class AdMod {
  static Completer<AdMod> _initialized;

  static initialize() async {
    if (_initialized == null) {
      _initialized = new Completer();
      final map = (await Settings).advertisement.admod;
      _initialized.complete(new AdMod(map));
    }
    return _initialized.future;
  }

  static showInterstitial() async => (await initialize())._invoke('showInterstitial');

  static position(String name) => context['AdMob']['AD_POSITION'][name];

  final Map<String, Map<String, dynamic>> _src;
  AdMod(this._src) {
    _invoke('createBanner', {'adId': idBanner, 'position': position(posBanner), 'autoShow': true});
    _invoke('prepareInterstitial', {'adId': idInterstitial, 'autoShow': false});
  }

  _invoke(String name, [Map params = const {}]) {
    _logger.info(() => "Invoking ${name}: ${params}");
    context['AdMod'].callMethod(name, new JsObject.jsify(params));
  }

  Map<String, String> get _banner => _src['banner'];
  String get idBanner => _banner['id'];
  String get posBanner => _banner['position'];

  Map<String, dynamic> get _interstitial => _src['interstitial'];
  String get idInterstitial => _interstitial['id'];
  List<String> get timingInterstitial => _interstitial['timings'];
}
