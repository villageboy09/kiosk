import 'package:cropsync/theme/app_text.dart';
import 'package:flutter/widgets.dart';

/// Static-UI text style on the app font (Google Sans, Tiro Telugu when the
/// locale is Telugu, with Telugu/Devanagari fallbacks). Takes the size /
/// weight / colour / height of [t].
TextStyle detailUi(BuildContext context, TextStyle t) => appStyle(
      context,
      size: t.fontSize,
      weight: t.fontWeight,
      color: t.color,
      height: t.height,
    );
