import 'package:flutter/material.dart';

/// The same Vendo brand palette the Rider app uses.
///
///  • Prune   → dark headers, primary buttons, main text
///  • Brique  → the single accent (status, links)
///  • Lin     → soft gold for key numbers on dark
///  • Raisin  → icons and secondary tones
class VColors {
  static const prune = Color(0xFF412143);
  static const pruneLight = Color(0xFF55295A);
  static const brique = Color(0xFFBF5E40);
  static const lin = Color(0xFFDBC583);
  static const raisin = Color(0xFF815488);

  static const background = Color(0xFFFAF7F5);
  static const ink = Color(0xFF2A1B2C);
  static const muted = Color(0xFF8C8290);
  static const border = Color(0xFFECE6EA);
  static const disabled = Color(0xFFD9D2DA);

  static const raisinSoft = Color(0xFFF4EDF5);
  static const briqueSoft = Color(0xFFF8EAE5);
  static const goldSoft = Color(0xFFF8F1DC);

  static const green = Color(0xFF2E7D32);
  static const greenSoft = Color(0xFFE7F3E8);
  static const red = Color(0xFFB3261E);
  static const redSoft = Color(0xFFFBE9E7);

  static const shadow = Color(0x1A412143);
}

const double vRadius = 16;

class VendoTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: VColors.prune,
      primary: VColors.prune,
      secondary: VColors.brique,
      surface: Colors.white,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: VColors.background,
      textTheme: base.textTheme.apply(
        bodyColor: VColors.ink,
        displayColor: VColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: VColors.ink,
        titleTextStyle: TextStyle(
          color: VColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: VColors.muted, fontSize: 14.5),
        labelStyle: const TextStyle(color: VColors.muted, fontSize: 14),
        prefixIconColor: VColors.raisin,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: inputBorder(VColors.border, 1.2),
        enabledBorder: inputBorder(VColors.border, 1.2),
        focusedBorder: inputBorder(VColors.prune, 1.6),
        errorBorder: inputBorder(VColors.red, 1.2),
        focusedErrorBorder: inputBorder(VColors.red, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VColors.prune,
          foregroundColor: Colors.white,
          disabledBackgroundColor: VColors.disabled,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VColors.prune,
          side: const BorderSide(color: VColors.border, width: 1.4),
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VColors.raisin,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VColors.prune,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: VColors.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VColors.prune,
        linearTrackColor: VColors.border,
      ),
    );
  }
}
