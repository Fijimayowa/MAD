import 'package:flutter/material.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(DirectoryApp(helper: helper));
}

class DirectoryApp extends StatelessWidget {
  final DatabaseHelper helper;
  const DirectoryApp({super.key, required this.helper});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      home: RosterScreen(helper: helper),
    );
  }
}

class RosterScreen extends StatefulWidget {
  final DatabaseHelper helper;
  const RosterScreen({super.key, required this.helper});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // Reads rows + count. Returns true on success.
  Future<bool> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return false;
      setState(() {
        _rows = rows;
        _count = count;
        _readError = null;
        _loading = false;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not read the roster. Tap Refresh to retry.';
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

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required.';
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse((value ?? '').trim());
    if (age == null) return 'Age must be a whole number.';
    if (age < 0 || age > 130) return 'Age must be from 0 to 130.';
    return null;
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();
    _selectedId = null;
  }

  Future<void> _onSave() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _feedback = 'Invalid input. Nothing was saved.');
      return;
    }
    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());
    final editingId = _selectedId;

    setState(() {
      _busy = true;
      _feedback = null;
    });

    String message;
    bool writeSucceeded = false;
    try {
      if (editingId == null) {
        final id = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
        message = 'Added $name (age $age) with ID $id.';
        writeSucceeded = true;
      } else {
        final updated = await widget.helper.update({
          DatabaseHelper.columnId: editingId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
        if (updated == 1) {
          message = 'Updated ID $editingId. Rows affected: $updated.';
          writeSucceeded = true;
        } else {
          message = 'ID $editingId was not found (rows affected: $updated).';
          // Row is gone; drop the stale edit selection.
          writeSucceeded = true;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Write failed: $error\n$stackTrace');
      message = 'Could not save. Your input was kept. Please try again.';
    }

    if (!mounted) return;
    if (writeSucceeded) {
      _formKey.currentState?.reset();
      _clearForm();
    }
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = (writeSucceeded && !refreshed)
          ? 'Saved, but refresh failed. Tap Refresh.'
          : message;
    });
  }

  void _onEdit(Map<String, dynamic> row) {
    if (_busy) return;
    setState(() {
      _selectedId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = 'Editing ID $_selectedId.';
    });
  }

  void _onCancelEdit() {
    if (_busy) return;
    setState(() {
      _formKey.currentState?.reset();
      _clearForm();
      _feedback = 'Edit cancelled. Nothing was written.';
    });
  }

  Future<void> _onDelete(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete ID $id ($name)? This cannot be undone.'),
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
    if (confirmed != true || !mounted) {
      if (mounted) {
        setState(() => _feedback = 'Delete cancelled. Nothing was written.');
      }
      return;
    }

    setState(() {
      _busy = true;
      _feedback = null;
    });
    String message;
    try {
      final deleted = await widget.helper.delete(id);
      if (deleted == 1) {
        message = 'Deleted ID $id. Rows affected: $deleted.';
      } else {
        message = 'ID $id was not found (rows affected: $deleted).';
      }
      if (_selectedId == id) {
        _formKey.currentState?.reset();
        _clearForm();
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');
      message = 'Could not delete. Please try again.';
    }
    final refreshed = await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = refreshed ? message : '$message Refresh failed. Tap Refresh.';
    });
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_readError != null) {
      return Center(child: Text(_readError!));
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No festival guests yet. Add the first one!'),
      );
    }
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final row = _rows[i];
        final id = row[DatabaseHelper.columnId];
        return ListTile(
          title: Text('${row[DatabaseHelper.columnName]}'),
          subtitle: Text('ID: $id  |  Age: ${row[DatabaseHelper.columnAge]}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _onEdit(row),
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _onDelete(row),
                child: const Text('Delete'),
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
      appBar: AppBar(title: const Text('Fall Festival Roster')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: _validateName,
                  ),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'),
                    validator: _validateAge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _onSave,
                  child: Text(_selectedId == null ? 'Add' : 'Save'),
                ),
                OutlinedButton(
                  onPressed: (_busy || _selectedId == null)
                      ? null
                      : _onCancelEdit,
                  child: const Text('Cancel edit'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _onRefresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Guests: $_count',
              style: Theme.of(context).textTheme.titleMedium,
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
