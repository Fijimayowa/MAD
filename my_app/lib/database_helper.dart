import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _databaseName = 'roster.db';
  static const _databaseVersion = 1;

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
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnName TEXT NOT NULL,
            $columnAge INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('DatabaseHelper.init() must be called first.');
    }
    return db;
  }

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
}
