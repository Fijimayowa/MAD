import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _board = BoardService.instance;
  final _controller = TextEditingController();
  late final Stream<List<Message>> _stream = _board.messagesStream(); // one subscription
  late String _pendingId = _board.newMessageId(); // reused on retry => idempotent create
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _post() async {
    final text = _controller.text.trim();
    final user = AuthService.instance.currentUser;
    if (_sending || text.isEmpty || user == null) return;
    setState(() => _sending = true);
    try {
      await _board.createMessage(
        id: _pendingId,
        text: text,
        authorUid: user.uid,
        authorName: user.displayName ?? 'Anonymous',
      );
      _controller.clear();
      _pendingId = _board.newMessageId(); // new compose attempt
    } catch (e) {
      _snack(BoardService.friendlyError(e)); // keep _pendingId so a retry can't duplicate
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit(Message m) async {
    final newText = await showDialog<String>(context: context, builder: (_) => _EditDialog(initial: m.text));
    if (newText == null || newText.trim().isEmpty || newText.trim() == m.text) return;
    try {
      await _board.updateMessage(m.id, newText);
    } catch (e) {
      _snack(BoardService.friendlyError(e));
    }
  }

  Future<void> _delete(Message m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _board.deleteMessage(m.id);
    } catch (e) {
      _snack(BoardService.friendlyError(e));
    }
  }

  String _when(DateTime? d) {
    if (d == null) return 'sending…';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatboards'),
        actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: AuthService.instance.signOut)],
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(BoardService.friendlyError(snap.error!)));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final msgs = snap.data!;
              if (msgs.isEmpty) {
                return const Center(child: Text('No messages yet. Be the first to post!'));
              }
              return ListView.builder(
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[i];
                  final mine = m.authorUid == uid;
                  return ListTile(
                    title: Text(m.text),
                    subtitle: Text('${m.authorName} · ${_when(m.createdAt)}${m.editedAt != null ? ' (edited)' : ''}'),
                    // Hiding buttons is UX only; firestore.rules is the real enforcement.
                    trailing: mine
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(m)),
                            IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(m)),
                          ])
                        : null,
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'Write a message', counterText: ''),
                  onSubmitted: (_) => _post(),
                ),
              ),
              IconButton.filled(
                onPressed: _sending ? null : _post,
                icon: _sending
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _EditDialog extends StatefulWidget {
  final String initial;
  const _EditDialog({required this.initial});
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: _c, maxLength: 500, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Save')),
        ],
      );
}
