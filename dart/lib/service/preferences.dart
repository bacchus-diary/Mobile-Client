library bacchus_diary.service.preferences;

import 'dart:async';

import 'package:logging/logging.dart';

import 'package:bacchus_diary/service/aws/cognito.dart';

final _logger = new Logger('Preferences');

class Preferences {
  static const LIMIT_ALWAYS_TAKE = 5;

  static const DATASET_PHOTO = 'photo';
  static const KEY_PHOTO_ALWAYSTAKE = 'always_take';
  static const KEY_PHOTO_TAKINGCOUNT = 'taking_count';

  static Future<bool> getPhotoAlwaysTake() async {
    final p = await CognitoSync.getDataset(DATASET_PHOTO);
    return 'true' == await p.get(KEY_PHOTO_ALWAYSTAKE);
  }

  static Future<Null> setPhotoAlwaysTake(bool value) async {
    final p = await CognitoSync.getDataset(DATASET_PHOTO);
    await p.put(KEY_PHOTO_ALWAYSTAKE, value.toString());
    if (!value) {
      await p.put(KEY_PHOTO_TAKINGCOUNT, '0');
    }
  }

  static Future<Null> addPhotoTaking(bool value) async {
    final p = await CognitoSync.getDataset(DATASET_PHOTO);
    getValue() async {
      if (value) {
        final pre = await p.get(KEY_PHOTO_TAKINGCOUNT) ?? '0';
        return int.parse(pre) + 1;
      } else {
        return 0;
      }
    }
    final count = await getValue();
    await p.put(KEY_PHOTO_TAKINGCOUNT, count.toString());

    if (LIMIT_ALWAYS_TAKE < count) await setPhotoAlwaysTake(true);
  }
}
