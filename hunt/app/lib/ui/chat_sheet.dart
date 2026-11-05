import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/errors.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

Future<void> showChatSheet(BuildContext context, Game game, Player me) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: _ChatSheet(game: game, me: me)),
    );

class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet({required this.game, required this.me});

  final Game game;
  final Player me;

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(repositoryProvider).sendMessage(widget.game.id, text);
      _text.clear();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final messages = ref.watch(messagesProvider(widget.game.id)).valueOrNull ?? const <ChatMessage>[];
    final players = ref.watch(playersProvider(widget.game.id)).valueOrNull ?? const <Player>[];
    final names = {for (final p in players) p.id: p.name};
    final teamColor = HuntColors.team(widget.me.team);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          ListTile(title: Text(l.chat, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: teamColor))),
          Expanded(
            child: messages.isEmpty
                ? Center(child: Text(l.chatEmpty))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[messages.length - 1 - i];
                      final mine = m.playerId == widget.me.id;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: mine ? teamColor.withValues(alpha: 0.35) : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (!mine)
                              Text(names[m.playerId] ?? '?', style: TextStyle(color: teamColor, fontWeight: FontWeight.w700)),
                            Text(m.text, style: const TextStyle(fontSize: 16)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: widget.me.isActive
                  ? Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          maxLength: 500,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(hintText: l.chatHint, counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(iconSize: 28, onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
                    ])
                  : Text(l.chatSpectator),
            ),
          ),
        ],
      ),
    );
  }
}
