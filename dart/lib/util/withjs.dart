library bacchus_diary.withjs;

import 'dart:convert';
import 'dart:js';

String stringify(obj) => context['JSON'].callMethod('stringify', [obj]);

Map jsmap(JsObject obj) => obj == null ? {} : JSON.decode(stringify(obj));
