import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "travel_app.db";
  static const _databaseVersion = 1;
  static const table = 'saved_places';

  static const columnId = 'id';
  static const columnName = 'name';
  static const columnType = 'type';
  static const columnDestination = 'destination';
  static const columnImageUrl = 'imageUrl';
  static const columnRating = 'rating';
  static const columnReviewCount = 'reviewCount';

  // Make this a singleton class
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Only have a single app-wide reference to the database
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnType TEXT NOT NULL,
        $columnDestination TEXT NOT NULL,
        $columnImageUrl TEXT,
        $columnRating REAL NOT NULL,
        $columnReviewCount INTEGER NOT NULL
      )
    ''');
  }

  // Helper methods
  Future<int> insertPlace(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllPlaces() async {
    Database db = await instance.database;
    return await db.query(table);
  }

  Future<int> deletePlace(String id) async {
    Database db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> queryRowCount() async {
    Database db = await instance.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $table'),
        ) ??
        0;
  }

  Future<bool> isPlaceSaved(String id) async {
    Database db = await instance.database;
    final maps = await db.query(
      table,
      columns: [columnId],
      where: '$columnId = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }
}
