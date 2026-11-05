import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../data/errors.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Game> _openGames = const [];

  @override
  void initState() {
    super.initState();
    if (Config.isConfigured) _signIn();
  }

  Future<void> _signIn() async {
    final repo = ref.read(repositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.ensureSignedIn();
      final games = await repo.myOpenGames();
      if (mounted) setState(() => _openGames = games);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<Game> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(repositoryProvider).ensureSignedIn();
      final game = await action();
      if (mounted) context.go('/game/${game.id}');
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!Config.isConfigured) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.notConfigured))));
    }
    final repo = ref.read(repositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text(
              l.appTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: HuntColors.hunter,
                  ),
            ),
            const SizedBox(height: 8),
            Text(l.startTagline, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            if (_openGames.isNotEmpty) ...[
              for (final g in _openGames)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.go('/game/${g.id}'),
                    icon: const Icon(Icons.replay),
                    label: Text('${l.startOpenGames} · ${g.code}'),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _name,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.startNameLabel),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : () => _run(() => repo.createGame(_name.text)),
              child: Text(l.startCreate),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(l.startOr, textAlign: TextAlign.center),
            ),
            TextField(
              controller: _code,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                _UpperCaseFormatter(),
              ],
              style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: l.startCodeLabel),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              onPressed: _busy ? null : () => _run(() => repo.joinGame(_code.text, _name.text)),
              child: Text(l.startJoin),
            ),
            if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
