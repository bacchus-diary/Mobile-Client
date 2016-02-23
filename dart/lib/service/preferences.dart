library bacchus_diary.service.preferences;

import 'dart:async';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/service/aws/cognito.dart';

final _logger = new Logger('Preferences');

class Preferences {
  static const DATASET_PHOTO = 'photo';
  static const KEY_PHOTO_ALWAYSTAKE = 'always_take';

  static Future<bool> getPhotoAlwaysTake() async {
    final p = await CognitoSync.getDataset(DATASET_PHOTO);
    return 'true' == await p.get(KEY_PHOTO_ALWAYSTAKE);
  }

  static Future<Null> setPhotoAlwaysTake(bool value) async {
    final p = await CognitoSync.getDataset(DATASET_PHOTO);
    await p.put(KEY_PHOTO_ALWAYSTAKE, value.toString());
  }
}
