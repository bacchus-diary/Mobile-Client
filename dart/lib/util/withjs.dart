library bacchus_diary.withjs;

import 'dart:js';

String stringify(obj) => context['JSON'].callMethod('stringify', [obj]);
