import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const bleu = Color(0xFF0F4FA5);
  static const bleuFonce = Color(0xFF0A3678);
  static const bleuPale = Color(0x140F4FA5);
  static const orange = Color(0xFFF2812D);
  static const orangePale = Color(0x33F2812D);
  static const fond = Color(0xFFF4F6F9);
  static const surface = Colors.white;
  static const texte = Color(0xFF14202A);
  static const texteDoux = Color(0xFF5E6B74);
  static const bordure = Color(0xFFDDE3E6);
  static const erreur = Color(0xFFC0392B);
  static const superpositionClaire = Color(0x66FFFFFF);
  static const transparent = Colors.transparent;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

abstract final class AppRadii {
  static const small = 8.0;
  static const field = 12.0;
  static const card = 16.0;
  static const largeCard = 24.0;
  static const pill = 20.0;
}

abstract final class AppTheme {
  static const animationDuration = Duration(milliseconds: 280);

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.bleu,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.bleu,
          secondary: AppColors.orange,
          onSecondary: AppColors.texte,
          secondaryContainer: AppColors.orangePale,
          onSecondaryContainer: AppColors.texte,
          surface: AppColors.surface,
          error: AppColors.erreur,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.fond,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _MecaPageTransitionsBuilder(),
          TargetPlatform.iOS: _MecaPageTransitionsBuilder(),
          TargetPlatform.linux: _MecaPageTransitionsBuilder(),
          TargetPlatform.macOS: _MecaPageTransitionsBuilder(),
          TargetPlatform.windows: _MecaPageTransitionsBuilder(),
        },
      ),
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        headlineLarge: GoogleFonts.sora(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.texte,
        ),
        headlineMedium: GoogleFonts.sora(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.texte,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.texte,
        ),
        bodyLarge: GoogleFonts.manrope(fontSize: 16, color: AppColors.texte),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: const TextStyle(color: AppColors.texteDoux),
        hintStyle: const TextStyle(color: AppColors.texteDoux),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.bordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.bleu, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.erreur),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.erreur, width: 1.5),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          side: const BorderSide(color: AppColors.bordure),
        ),
        labelStyle: const TextStyle(color: AppColors.texte),
        secondaryLabelStyle: const TextStyle(color: AppColors.texte),
        selectedColor: AppColors.bleu.withValues(alpha: 0.12),
        checkmarkColor: AppColors.bleu,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.bordure),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
        ),
      ),
    );
  }
}

class _MecaPageTransitionsBuilder extends PageTransitionsBuilder {
  const _MecaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.025, 0),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}
