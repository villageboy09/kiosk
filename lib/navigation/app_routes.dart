import 'package:flutter/material.dart';

class AppRoutes {
  static Route<T> fade<T>(Widget page, {int ms = 400}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration(milliseconds: ms),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static Route<T> slideFromRight<T>(Widget page, {int ms = 300}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration(milliseconds: ms),
      reverseTransitionDuration: Duration(milliseconds: ms),
      transitionsBuilder: (_, animation, __, child) {
        final slideIn = Tween<Offset>(
          begin: const Offset(0.12, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation);

        final fadeIn = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation);

        return SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: child,
          ),
        );
      },
    );
  }

  static Route<T> slideFromLeft<T>(Widget page, {int ms = 300}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration(milliseconds: ms),
      reverseTransitionDuration: Duration(milliseconds: ms),
      transitionsBuilder: (_, animation, __, child) {
        final slideIn = Tween<Offset>(
          begin: const Offset(-0.12, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation);

        final fadeIn = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.fastOutSlowIn)).animate(animation);

        return SlideTransition(
          position: slideIn,
          child: FadeTransition(
            opacity: fadeIn,
            child: child,
          ),
        );
      },
    );
  }

  static Route<T> slideFromBottom<T>(Widget page, {int ms = 400}) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration(milliseconds: ms),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
          child: child,
        );
      },
    );
  }

  static Route<T> noAnimation<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}
