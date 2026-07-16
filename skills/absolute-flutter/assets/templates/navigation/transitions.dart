// lib/navigation/helper/transitions.dart
//
// Declarative page transitions. A feature route picks a transition by enum value
// (`AppGoRoute(defaultTransition: Transitions.slideLeft)`); the factory turns
// that enum into a `CustomTransitionPage`. This hides every `pageBuilder` /
// `transitionsBuilder` from the route declarations — adding a new transition is
// one enum value + one `case`, not a per-route closure.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The set of supported transitions. One value per visual effect.
enum Transitions { none, slideLeft, slideRight, slideTop, slideBottom, fadeIn }

/// No animation — used by shell tabs and instant replacements.
class NoneTransition<T> extends CustomTransitionPage<T> {
  NoneTransition({required Widget child, Duration? transitionDuration})
      : super(
          child: child,
          transitionDuration: transitionDuration ?? Duration.zero,
          transitionsBuilder: (_, __, ___, child) => child,
        );
}

/// Slide in from the right edge (the default forward push).
class SlideLeftTransition<T> extends CustomTransitionPage<T> {
  SlideLeftTransition({required Widget child, Duration? transitionDuration})
      : super(
          child: child,
          transitionDuration: transitionDuration ?? const Duration(milliseconds: 200),
          transitionsBuilder: _builder,
        );

  static Widget _builder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeIn)),
      child: child,
    );
  }
}

/// Slide down from the top edge — used for modal-ish full screens (e.g. login).
class SlideTopTransition<T> extends CustomTransitionPage<T> {
  SlideTopTransition({required Widget child, Duration? transitionDuration})
      : super(
          child: child,
          transitionDuration: transitionDuration ?? const Duration(milliseconds: 200),
          transitionsBuilder: _builder,
        );

  static Widget _builder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeIn)),
      child: child,
    );
  }
}

/// Cross-fade.
class FadeInTransition<T> extends CustomTransitionPage<T> {
  FadeInTransition({required Widget child, Duration? transitionDuration})
      : super(
          child: child,
          transitionDuration: transitionDuration ?? const Duration(milliseconds: 200),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        );
}

/// Turns a [Transitions] enum value into the matching [CustomTransitionPage].
/// [AppGoRoute] calls this when a route declares only a `builder`.
class TransitionsFactory {
  const TransitionsFactory(this.transition);

  final Transitions transition;

  CustomTransitionPage<T> transitionBuilder<T>(
    Widget child, {
    Duration transitionDuration = const Duration(milliseconds: 200),
  }) {
    switch (transition) {
      case Transitions.slideLeft:
      case Transitions.slideRight:
        return SlideLeftTransition<T>(child: child, transitionDuration: transitionDuration);
      case Transitions.slideTop:
      case Transitions.slideBottom:
        return SlideTopTransition<T>(child: child, transitionDuration: transitionDuration);
      case Transitions.fadeIn:
        return FadeInTransition<T>(child: child, transitionDuration: transitionDuration);
      case Transitions.none:
        return NoneTransition<T>(child: child, transitionDuration: transitionDuration);
    }
  }
}
