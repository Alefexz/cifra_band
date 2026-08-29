import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cifra_band.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB, onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    });
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE saved_songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        content TEXT NOT NULL,
        original_key TEXT NOT NULL,
        source_url TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE setlists (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, event_date TEXT, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE setlist_items (
        id TEXT PRIMARY KEY, setlist_id TEXT NOT NULL, song_id TEXT NOT NULL,
        position_index INTEGER NOT NULL, transposed_key TEXT, notes TEXT,
        FOREIGN KEY (setlist_id) REFERENCES setlists (id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES saved_songs (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> saveSong(Map<String, dynamic> song) async {
    final db = await instance.database;
    await db.insert('saved_songs', song, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}