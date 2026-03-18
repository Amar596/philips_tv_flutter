import 'package:philips_tv_flutter/models/wauly_event.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class EventDatabase {
  static final EventDatabase instance = EventDatabase._init();
  static Database? _database;

  EventDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('events.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);

    print('📁 Database path: $path');

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rawMessage TEXT NOT NULL,
        receivedAt TEXT NOT NULL,
        type INTEGER NOT NULL
      )
    ''');
  }

  Future<int> createEvent(WaulyEvent event) async {
    final db = await database;
    //final db = await instance.database;
    return await db.insert('events', {
      'rawMessage': event.rawMessage,
      'receivedAt': event.receivedAt.toIso8601String(),
      'type': event.type.index,
    });
  }

  Future<List<WaulyEvent>> readAllEvents() async {
    final db = await database;
    //final db = await instance.database;
    final result = await db.query('events', orderBy: 'receivedAt DESC');

    return result
        .map((json) => WaulyEvent(
              rawMessage: json['rawMessage'] as String,
              receivedAt: DateTime.parse(json['receivedAt'] as String),
              type: EventType.values[json['type'] as int],
            ))
        .toList();
  }

  Future<int> deleteAll() async {
    final db = await database;
    //final db = await instance.database;
    return await db.delete('events');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
