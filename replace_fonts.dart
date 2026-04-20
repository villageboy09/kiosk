import 'dart:io';
void main() {
  final files = ['lib/screens/operator/operator_dashboard.dart', 'lib/screens/operator/operator_history_screen.dart', 'lib/screens/operator/operator_profile_screen.dart'];
  for (var f in files) {
    var file = File(f);
    if (!file.existsSync()) continue;
    var content = file.readAsStringSync();
    content = content.replaceAll('GoogleFonts.inter(', 'AppTheme.getTextStyle(context, ');
    content = content.replaceAll('GoogleFonts.poppins(', 'AppTheme.getTextStyle(context, ');
    if (!content.contains('package:cropsync/theme/app_theme.dart')) {
      content = content.replaceFirst('import \'package:flutter/material.dart\';', 'import \'package:flutter/material.dart\';\nimport \'package:cropsync/theme/app_theme.dart\';');
    }
    file.writeAsStringSync(content);
  }
}
