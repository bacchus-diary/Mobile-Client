library bacchus_diary.settings;

import 'dart:async';
import 'dart:js';

import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

import 'package:bacchus_diary/service/aws/cognito.dart';
import 'package:bacchus_diary/service/aws/s3file.dart';
import 'package:bacchus_diary/service/aws/sns.dart';
import 'package:bacchus_diary/service/admob.dart';
import 'package:bacchus_diary/util/cordova.dart';

final Logger _logger = new Logger('Settings');

Completer<_Settings> _initializing;
/**
 * This method will be invoked automatically.
 * But you can invoke manually to setup your own map of test.
 *
 * @param onFail works only on failed to get settings
 */
Future<_Settings> _initialize() async {
  if (_initializing == null) {
    _initializing = new Completer();
    getting() async {
      try {
        final local = await CognitoSettings.value;
        final server = loadYaml(await S3File.read('unauthorized/client.yaml', local.s3Bucket));
        final map = new Map.from(server);
        _logger.config("Initializing...");
        _initializing.complete(new _Settings(local, map));
      } catch (ex) {
        _logger.warning("Failed to read settings file: ${ex}");
        if ("$ex".contains("RequestTimeTooSkewed")) {
          context['navigator']['notification'].callMethod('alert', [
            "It seems that the clock is not correct. Please adjust it.",
            (_) {
              getting();
            },
            "Skewed Clock",
            "DONE"
          ]);
        } else {
          _initializing.completeError(ex);
        }
      }
      // Start background services
      SNS.init();
      AdMob.initialize();
    }
    getting();
  }
  return _initializing.future;
}

Future<_Settings> get Settings => _initialize();

Future<Map> get AuthorizedSettings async {
  final Map settings = loadYaml(await S3File.read('authorized/settings.yaml', (await Settings).s3Bucket));
  _logger.config(() => "Authorized settings loaded");
  return settings;
}

class _Settings {
  _Settings(this._local, this._map);
  final CognitoSettings _local;
  final Map _map;

  String get awsRegion => _local.region;
  String get s3Bucket => _local.s3Bucket;
  String get cognitoPoolId => _local.poolId;

  String get appName => _map['appName'];
  String get googleProjectNumber => _map['googleProjectNumber'];
  String get googleKey => _map['googleBrowserKey'];
  String get snsPlatformArn => _map['snsPlatformArn'][isAndroid ? 'google' : 'apple'];

  _Photo _photo;
  _Photo get photo {
    if (_photo == null) _photo = new _Photo(_map['photo']);
    return _photo;
  }

  _Advertisement _advertisement;
  _Advertisement get advertisement {
    if (_advertisement == null) _advertisement = new _Advertisement(_map['advertisement']);
    return _advertisement;
  }

  _Amazon _amazon;
  _Amazon get amazon {
    if (_amazon == null) _amazon = new _Amazon(_map['amazon']);
    return _amazon;
  }
}

class _Photo {
  _Photo(this._map);
  final Map _map;

  Duration get urlTimeout => new Duration(seconds: _map['urlTimeout']);
}

class _Advertisement {
  final Map _map;
  _Advertisement(Map map) : this._map = new Map.unmodifiable(map);

  Map get admod => _map['AdMod'];
}

class _Amazon {
  final Map _map;
  _Amazon(this._map);

  String get accessKey => _map['AWSAccessKeyId'];
  String get secretKey => _map['AWSSecretKey'];
  String get associateTag => _map['AssociatesID'];
}
