import 'package:flutter/material.dart';
import '../domain/finance.dart';

const ink = Color(0xff302044),
    muted = Color(0xff8b7d9c),
    purple = Color(0xff873cff),
    pink = Color(0xffef75b4),
    lavender = Color(0xfff0e6fc),
    peach = Color(0xffffe9dc);
const primaryGradient = LinearGradient(
  colors: [purple, Color(0xffb15af2), pink],
  begin: Alignment.centerRight,
  end: Alignment.centerLeft,
);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Vazirmatn',
  scaffoldBackgroundColor: const Color(0xfffaf7fd),
  colorScheme: ColorScheme.fromSeed(seedColor: purple, surface: Colors.white),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, fontSize: 14),
    titleLarge: TextStyle(
      color: ink,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
  ),
  dividerColor: lavender,
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      backgroundColor: lavender,
      foregroundColor: purple,
      side: const BorderSide(color: Colors.white, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      minimumSize: const Size(0, 52),
      textStyle: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xfffcfaff),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: lavender),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: lavender),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: lavender,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: gradient == null ? (color ?? Colors.white) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff6e3fa3).withValues(alpha: .045),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const GradientButton(this.label, {super.key, this.onPressed, this.icon});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: primaryGradient,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: purple.withValues(alpha: .16),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    ),
  );
}

class Amount extends StatelessWidget {
  final num? value;
  final bool compact;
  final Color color;
  final double size;
  const Amount(
    this.value, {
    super.key,
    this.compact = false,
    this.color = ink,
    this.size = 16,
  });
  @override
  Widget build(BuildContext context) => Text(
    money(value, compact: compact),
    textDirection: TextDirection.rtl,
    style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const Tag(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color ?? lavender,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: ink,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.caption, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

Future<T?> showForm<T>(BuildContext context, Widget form) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xfffaf7fd),
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: form,
      ),
    );
Future<void> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }
}

Future<Month?> pickMonth(BuildContext context, Month initial) async {
  var year = initial.year;
  return showDialog<Month>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => AlertDialog(
        title: Row(
          children: [
            IconButton(
              onPressed: () => set(() => year--),
              icon: const Icon(Icons.chevron_right),
            ),
            Expanded(child: Text(persian(year), textAlign: TextAlign.center)),
            IconButton(
              onPressed: () => set(() => year++),
              icon: const Icon(Icons.chevron_left),
            ),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              12,
              (i) => SizedBox(
                width: 94,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor:
                        year == initial.year && i + 1 == initial.number
                        ? lavender
                        : null,
                  ),
                  onPressed: () => Navigator.pop(context, Month(year, i + 1)),
                  child: Text(monthNames[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
