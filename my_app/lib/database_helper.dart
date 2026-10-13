import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  static const _databaseName = 'roster.db';
  static const _databaseVersion = 2;

  static const table = 'roster';
  static const columnId = 'id';
  static const columnName = 'name';
  static const columnAge = 'age';

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createPartOneTables(db);
        await _createCatalogueTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCatalogueTables(db);
        }
      },
    );
  }

  Future<void> _createPartOneTables(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON cards(folder_id)',
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('DatabaseHelper.init() must be called first.');
    }
    return db;
  }

  // Part I: guest roster
  Future<int> insert(Map<String, dynamic> row) async {
    return _database.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return _database.query(table, orderBy: '$columnId ASC');
  }

  Future<int> queryRowCount() async {
    final result = await _database.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) async {
    final id = row[columnId];
    return _database.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return _database.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  // Part II: folders
  Future<int> insertFolder(String name) async {
    try {
      return await _database.insert('folders', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw DuplicateFolderException(name);
      }
      rethrow;
    }
  }

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _database.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id
      ORDER BY f.name COLLATE NOCASE ASC, f.id ASC
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<int> deleteFolder(int id) async {
    return _database.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // Part II: cards
  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _database.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<int> insertCard(CardRecord card) async {
    return _database.insert('cards', card.toMap());
  }

  Future<int> updateCard(CardRecord card) async {
    return _database.update(
      'cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) async {
    return _database.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  // Read-only diagnostics for T1 evidence
  Future<String> diagnostics() async {
    final db = _database;
    final version =
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version'));
    final fk = Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys'));
    final fkList = await db.rawQuery('PRAGMA foreign_key_list(cards)');
    final idxList = await db.rawQuery('PRAGMA index_list(cards)');
    final guests = await db.query(table, orderBy: '$columnId ASC');
    final folderCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM folders'));
    final cardCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cards'));

    final buffer = StringBuffer()
      ..writeln('PRAGMA user_version: $version')
      ..writeln('PRAGMA foreign_keys: $fk')
      ..writeln('foreign_key_list(cards): $fkList')
      ..writeln('index_list(cards): $idxList')
      ..writeln('Part I roster rows (${guests.length}):');
    for (final row in guests) {
      buffer.writeln('  $row');
    }
    buffer
      ..writeln('folders: $folderCount')
      ..writeln('cards: $cardCount');
    return buffer.toString();
  }
}
