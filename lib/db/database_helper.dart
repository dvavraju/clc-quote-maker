import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('clc_quotations.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE quotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_name TEXT NOT NULL,
        total_amount TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE quotation_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quotation_id INTEGER NOT NULL,
        event_name TEXT NOT NULL,
        event_date TEXT,
        display_order INTEGER NOT NULL,
        FOREIGN KEY (quotation_id) REFERENCES quotations (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE event_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER NOT NULL,
        service_name TEXT NOT NULL,
        FOREIGN KEY (event_id) REFERENCES quotation_events (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE quotation_deliverables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quotation_id INTEGER NOT NULL,
        deliverable_name TEXT NOT NULL,
        is_selected INTEGER NOT NULL DEFAULT 1,
        display_order INTEGER NOT NULL,
        FOREIGN KEY (quotation_id) REFERENCES quotations (id) ON DELETE CASCADE
      )
    ''');
  }

  // Quotation CRUD
  Future<int> createQuotation(Quotation quotation) async {
    final db = await instance.database;
    return await db.insert('quotations', quotation.toMap());
  }

  Future<List<Quotation>> getAllQuotations() async {
    final db = await instance.database;
    final result = await db.query('quotations', orderBy: 'created_at DESC');
    return result.map((json) => Quotation.fromMap(json)).toList();
  }

  Future<int> updateQuotation(Quotation quotation) async {
    final db = await instance.database;
    return await db.update(
      'quotations',
      quotation.toMap(),
      where: 'id = ?',
      whereArgs: [quotation.id],
    );
  }

  Future<int> deleteQuotation(int id) async {
    final db = await instance.database;
    return await db.delete(
      'quotations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Event CRUD
  Future<int> createEvent(QuotationEvent event) async {
    final db = await instance.database;
    return await db.insert('quotation_events', event.toMap());
  }

  Future<List<QuotationEvent>> getEventsForQuotation(int quotationId) async {
    final db = await instance.database;
    final result = await db.query(
      'quotation_events',
      where: 'quotation_id = ?',
      whereArgs: [quotationId],
      orderBy: 'display_order ASC',
    );
    return result.map((json) => QuotationEvent.fromMap(json)).toList();
  }

  // Service CRUD
  Future<int> createService(EventService service) async {
    final db = await instance.database;
    return await db.insert('event_services', service.toMap());
  }

  Future<List<EventService>> getServicesForEvent(int eventId) async {
    final db = await instance.database;
    final result = await db.query(
      'event_services',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
    return result.map((json) => EventService.fromMap(json)).toList();
  }

  // Deliverable CRUD
  Future<int> createDeliverable(QuotationDeliverable deliverable) async {
    final db = await instance.database;
    return await db.insert('quotation_deliverables', deliverable.toMap());
  }

  Future<List<QuotationDeliverable>> getDeliverablesForQuotation(int quotationId) async {
    final db = await instance.database;
    final result = await db.query(
      'quotation_deliverables',
      where: 'quotation_id = ?',
      whereArgs: [quotationId],
      orderBy: 'display_order ASC',
    );
    return result.map((json) => QuotationDeliverable.fromMap(json)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
