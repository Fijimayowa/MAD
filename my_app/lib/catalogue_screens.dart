import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'models.dart';

Future<bool> _confirmDelete(
  BuildContext context,
  String title,
  String body,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows the card artwork if image_ref works; otherwise a stable suit symbol.
/// image_ref may be null, an asset path ("assets/..."), or an http(s) URL.
class CardArt extends StatelessWidget {
  final String? imageRef;
  final String suit;
  final double size;
  const CardArt({
    super.key,
    required this.imageRef,
    required this.suit,
    this.size = 48,
  });

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(suitSymbol(suit), style: TextStyle(fontSize: size * 0.6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = imageRef?.trim();
    if (ref == null || ref.isEmpty) return _fallback(context);

    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          ref,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _fallback(context),
          errorBuilder: (context, error, stackTrace) => _fallback(context),
        ),
      );
    }
    if (ref.startsWith('assets/')) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          ref,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(context),
        ),
      );
    }
    // Malformed or unsupported reference: keep the row, show the fallback.
    return _fallback(context);
  }
}

// ===========================================================================
// Folder list
// ===========================================================================

class FolderListScreen extends StatefulWidget {
  final DatabaseHelper helper;
  const FolderListScreen({super.key, required this.helper});

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  final _nameController = TextEditingController();

  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<bool> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final folders = await widget.helper.getFoldersWithCounts();
      if (!mounted) return false;
      setState(() {
        _folders = folders;
        _readError = null;
        _loading = false;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Folder read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read folders. Tap Refresh to retry.';
        _loading = false;
      });
      return false;
    }
  }

  Future<void> _onRefresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onAddFolder() async {
    if (_busy) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _feedback = 'Folder name is required. Nothing was saved.');
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });

    String message;
    bool writeSucceeded = false;
    try {
      final id = await widget.helper.insertFolder(name);
      message = 'Created folder "$name" with ID $id.';
      writeSucceeded = true;
    } on DuplicateFolderException {
      message = 'A folder named "$name" already exists. Nothing was saved.';
    } catch (error, stackTrace) {
      debugPrint('Folder write failed: $error\n$stackTrace');
      message = 'Could not create the folder. Your input was kept.';
    }

    if (!mounted) return;
    if (writeSucceeded) _nameController.clear();
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = (writeSucceeded && !refreshed)
          ? 'Saved, but refresh failed. Tap Refresh.'
          : message;
    });
  }

  Future<void> _onDeleteFolder(Folder folder) async {
    if (_busy) return;
    final confirmed = await _confirmDelete(
      context,
      'Delete folder?',
      'Delete "${folder.name}" (ID ${folder.id}) and its ${folder.cardCount} '
          'card(s)? This cannot be undone.',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _feedback = 'Delete cancelled. Nothing was written.');
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });
    String message;
    try {
      final deleted = await widget.helper.deleteFolder(folder.id);
      message = deleted == 1
          ? 'Deleted folder ID ${folder.id}. Rows affected: $deleted. '
                'Cards it held: ${folder.cardCount}.'
          : 'Folder ID ${folder.id} was not found (rows affected: $deleted).';
    } catch (error, stackTrace) {
      debugPrint('Folder delete failed: $error\n$stackTrace');
      message = 'Could not delete the folder. Please try again.';
    }
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = refreshed ? message : '$message Refresh failed. Tap Refresh.';
    });
  }

  Future<void> _openFolder(Folder folder) async {
    if (_busy) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardListScreen(helper: widget.helper, folder: folder),
      ),
    );
    if (!mounted) return;
    await _load(); // counts may have changed
  }

  Future<void> _showDiagnostics() async {
    String text;
    try {
      text = await widget.helper.diagnostics();
    } catch (error) {
      text = 'Diagnostics failed: $error';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Database diagnostics'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_readError != null) return Center(child: Text(_readError!));
    if (_folders.isEmpty) {
      return const Center(child: Text('No folders yet. Create the first one!'));
    }
    return ListView.builder(
      itemCount: _folders.length,
      itemBuilder: (context, i) {
        final folder = _folders[i];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(folder.name),
          subtitle: Text('ID: ${folder.id}  |  Cards: ${folder.cardCount}'),
          onTap: _busy ? null : () => _openFolder(folder),
          trailing: IconButton(
            tooltip: 'Delete folder',
            icon: const Icon(Icons.delete),
            onPressed: _busy ? null : () => _onDeleteFolder(folder),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Database diagnostics',
            icon: const Icon(Icons.info_outline),
            onPressed: _busy ? null : _showDiagnostics,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'New folder'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _busy ? null : _onAddFolder,
                  child: const Text('Add folder'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _onRefresh,
                  child: const Text('Refresh'),
                ),
                Text(
                  'Folders: ${_folders.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (_feedback != null) Text(_feedback!),
            const Divider(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Card list for one folder
// ===========================================================================

class CardListScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final Folder folder;
  const CardListScreen({super.key, required this.helper, required this.folder});

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  List<CardRecord> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final cards = await widget.helper.getCards(widget.folder.id);
      if (!mounted) return false;
      setState(() {
        _cards = cards;
        _readError = null;
        _loading = false;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Card read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read cards. Tap Refresh to retry.';
        _loading = false;
      });
      return false;
    }
  }

  Future<void> _onRefresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm([CardRecord? card]) async {
    if (_busy) return;
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CardFormScreen(
          helper: widget.helper,
          folder: widget.folder,
          existing: card,
        ),
      ),
    );
    if (!mounted) return;
    if (message == null) {
      setState(
        () => _feedback = card == null
            ? 'Add cancelled. Nothing was written.'
            : 'Edit cancelled. Nothing was written.',
      );
      return;
    }
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      _feedback = refreshed ? message : '$message Refresh failed. Tap Refresh.';
    });
  }

  Future<void> _onDelete(CardRecord card) async {
    if (_busy) return;
    final confirmed = await _confirmDelete(
      context,
      'Delete card?',
      'Delete card ID ${card.id} ("${card.title}")? This cannot be undone.',
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _feedback = 'Delete cancelled. Nothing was written.');
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });
    String message;
    try {
      final deleted = await widget.helper.deleteCard(card.id!);
      message = deleted == 1
          ? 'Deleted card ID ${card.id}. Rows affected: $deleted.'
          : 'Card ID ${card.id} was not found (rows affected: $deleted).';
    } catch (error, stackTrace) {
      debugPrint('Card delete failed: $error\n$stackTrace');
      message = 'Could not delete the card. Please try again.';
    }
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = refreshed ? message : '$message Refresh failed. Tap Refresh.';
    });
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_readError != null) return Center(child: Text(_readError!));
    if (_cards.isEmpty) {
      return const Center(child: Text('This folder is empty. Add a card!'));
    }
    return ListView.builder(
      itemCount: _cards.length,
      itemBuilder: (context, i) {
        final card = _cards[i];
        final notes = card.notes.isEmpty ? '' : '\n${card.notes}';
        return ListTile(
          leading: CardArt(imageRef: card.imageRef, suit: card.suit),
          title: Text(card.title),
          subtitle: Text(
            'ID: ${card.id}  |  ${card.suit}  |  Folder ID: ${card.folderId}'
            '$notes',
          ),
          isThreeLine: card.notes.isNotEmpty,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit card',
                icon: const Icon(Icons.edit),
                onPressed: _busy ? null : () => _openForm(card),
              ),
              IconButton(
                tooltip: 'Delete card',
                icon: const Icon(Icons.delete),
                onPressed: _busy ? null : () => _onDelete(card),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : () => _openForm(),
                  child: const Text('Add card'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _onRefresh,
                  child: const Text('Refresh'),
                ),
                Text(
                  'Folder ID ${widget.folder.id}  |  Cards: ${_cards.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (_feedback != null) Text(_feedback!),
            const Divider(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// One form for Add and Edit
// ===========================================================================

class CardFormScreen extends StatefulWidget {
  final DatabaseHelper helper;
  final Folder folder;
  final CardRecord? existing;
  const CardFormScreen({
    super.key,
    required this.helper,
    required this.folder,
    this.existing,
  });

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageController;
  String? _suit;
  String? _suitError;
  bool _busy = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    final card = widget.existing;
    _titleController = TextEditingController(text: card?.title ?? '');
    _notesController = TextEditingController(text: card?.notes ?? '');
    _imageController = TextEditingController(text: card?.imageRef ?? '');
    _suit = card?.suit;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required.';
    return null;
  }

  Future<void> _onSave() async {
    if (_busy) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final suit = _suit;
    setState(() => _suitError = suit == null ? 'Choose a suit.' : null);
    if (!formOk || suit == null) {
      setState(() => _feedback = 'Invalid input. Nothing was saved.');
      return;
    }

    final imageText = _imageController.text.trim();
    final existing = widget.existing;
    final card = CardRecord(
      id: existing?.id,
      title: _titleController.text.trim(),
      suit: suit,
      notes: _notesController.text.trim(), // '' when omitted
      imageRef: imageText.isEmpty ? null : imageText, // NULL when omitted
      folderId: widget.folder.id,
    );

    setState(() {
      _busy = true;
      _feedback = null;
    });

    try {
      String message;
      if (existing == null) {
        final id = await widget.helper.insertCard(card);
        message =
            'Added "${card.title}" with ID $id in '
            '"${widget.folder.name}".';
      } else {
        final updated = await widget.helper.updateCard(card);
        message = updated == 1
            ? 'Updated card ID ${existing.id}. Rows affected: $updated.'
            : 'Card ID ${existing.id} was not found '
                  '(rows affected: $updated).';
      }
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (error, stackTrace) {
      debugPrint('Card write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = 'Could not save. Your input was kept. Please try again.';
      });
    }
  }

  void _onCancel() {
    if (_busy) return;
    Navigator.pop(context); // null result = nothing written
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit card' : 'Add card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Folder: ${widget.folder.name} (ID ${widget.folder.id})'),
            if (editing) Text('Editing card ID ${widget.existing!.id}'),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: _validateTitle,
                  ),
                  TextFormField(
                    controller: _notesController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  TextFormField(
                    controller: _imageController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Image reference (optional)',
                      helperText: 'Asset path (assets/...) or https URL. Blank = suit symbol.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Suit'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in kSuits)
                  ChoiceChip(
                    label: Text('${suitSymbol(s)} $s'),
                    selected: _suit == s,
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            _suit = selected ? s : null;
                            _suitError = null;
                          }),
                  ),
              ],
            ),
            if (_suitError != null)
              Text(
                _suitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _onSave,
                  child: Text(editing ? 'Save' : 'Add'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
            if (_feedback != null) Text(_feedback!),
          ],
        ),
      ),
    );
  }
}
