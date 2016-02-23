library bacchus_diary.page.preferences;

import 'dart:async';
import 'dart:html';

import 'package:angular/angular.dart';
import 'package:logging/logging.dart';
import 'package:paper_elements/paper_toggle_button.dart';

import 'package:bacchus_diary/service/aws/cognito.dart';
import 'package:bacchus_diary/service/facebook.dart';
import 'package:bacchus_diary/service/preferences.dart';
import 'package:bacchus_diary/util/fabric.dart';
import 'package:bacchus_diary/util/main_frame.dart';

final _logger = new Logger('PreferencesPage');

@Component(
    selector: 'preferences',
    templateUrl: 'packages/bacchus_diary/page/preferences.html',
    cssUrl: 'packages/bacchus_diary/page/preferences.css',
    useShadowDom: true)
class PreferencesPage extends MainPage {
  static const submitDuration = const Duration(seconds: 20);

  Timer _submitTimer;

  bool get isReady => true;

  PreferencesPage(Router router) : super(router);

  void onShadowRoot(ShadowRoot sr) {
    super.onShadowRoot(sr);
    FabricAnswers.eventContentView(contentName: "PreferencesPage");

    toggleButton(String parent, Future<bool> getValue()) async =>
        root.querySelector("${parent} paper-toggle-button") as PaperToggleButton..checked = await getValue();

    new Future.delayed(new Duration(milliseconds: 10), () async {
      toggleButton('#social #connection', () async => (await CognitoIdentity.credential).hasFacebook());
      toggleButton('#photo #taking', Preferences.getPhotoAlwaysTake);
    });
  }

  void detach() {
    super.detach();
    if (_submitTimer != null && _submitTimer.isActive) {
      _submitTimer.cancel();
    }
  }

  changeFacebook(event) async {
    final toggle = event.target as PaperToggleButton;
    _logger.fine(() => "Toggle Facebook: ${toggle.checked}");
    try {
      if (toggle.checked) {
        await FBConnect.login();
      } else {
        await FBConnect.logout();
      }
    } catch (ex) {
      _logger.warning(() => "Error: ${ex}");
    }
    toggle.checked = (await CognitoIdentity.credential).hasFacebook();
  }

  changeTaking(event) async {
    final toggle = event.target as PaperToggleButton;
    _logger.fine(() => "Toggle AlwaysTAKE: ${toggle.checked}");
    await Preferences.setPhotoAlwaysTake(toggle.checked);
  }
}
