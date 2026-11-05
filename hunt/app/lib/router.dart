import 'package:go_router/go_router.dart';

import 'ui/game_shell.dart';
import 'ui/start_screen.dart';
import 'ui/zone_picker_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartScreen()),
    GoRoute(
      path: '/game/:id',
      builder: (context, state) => GameShell(gameId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'zone',
          builder: (context, state) => ZonePickerScreen(gameId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
