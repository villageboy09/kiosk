import 'package:cropsync/theme/app_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Description paragraphs collapsed to 6 lines with a Read more toggle.
class ExpandableParagraphs extends StatefulWidget {
  final List<String> paragraphs;
  const ExpandableParagraphs({super.key, required this.paragraphs});

  @override
  State<ExpandableParagraphs> createState() => ExpandableParagraphsState();
}

class ExpandableParagraphsState extends State<ExpandableParagraphs> {
  static const int _maxLines = 6;
  bool _expanded = false;

  // Memoised overflow measurement (text, width, scale, locale, direction).
  Object? _measureKey;
  bool _measuredOverflow = false;

  bool _overflows(
      BuildContext context, String joined, TextStyle style, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final dir = Directionality.of(context);
    final key = Object.hash(joined, width, scaler.scale(15), locale, dir);
    if (key == _measureKey) return _measuredOverflow;
    final painter = TextPainter(
      text: TextSpan(
          text: joined, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: dir,
      textScaler: scaler,
      locale: locale,
      maxLines: _maxLines,
    )..layout(maxWidth: width);
    _measuredOverflow = painter.didExceedMaxLines;
    painter.dispose();
    _measureKey = key;
    return _measuredOverflow;
  }

  @override
  Widget build(BuildContext context) {
    final joined = widget.paragraphs.join('\n');
    final style = appStyle(context,
        text: joined, size: 15, color: const Color(0xFF475569), height: 1.65);

    return LayoutBuilder(builder: (context, c) {
      final overflows = _overflows(context, joined, style, c.maxWidth);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: (_expanded || !overflows)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.paragraphs.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: Text(widget.paragraphs[i], style: style),
                        ),
                      ],
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: Text(joined,
                        maxLines: _maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: style),
                  ),
          ),
          if (overflows)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr(_expanded ? 'pd_show_less' : 'pd_read_more'),
                    style: appStyle(context,
                        size: 14,
                        weight: FontWeight.w800,
                        color: const Color(0xFF15803D)),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
