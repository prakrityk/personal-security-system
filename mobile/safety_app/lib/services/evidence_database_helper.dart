/// Local Database Helper for Evidence
/// Manages local SQLite storage for offline evidence tracking
/// Location: lib/services/evidence_database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/evidence.dart';

class EvidenceDatabaseHelper {
  static final EvidenceDatabaseHelper instance = EvidenceDatabaseHelper._init();
  static Database? _database;

  EvidenceDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('evidence.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        user_id INTEGER,
        evidence_type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        file_url TEXT,
        upload_status TEXT NOT NULL DEFAULT 'pending',
        file_size INTEGER,
        duration INTEGER,
        created_at TEXT NOT NULL,
        uploaded_at TEXT
      )
    ''');

    // Fast lookups for the upload retry loop
    await db.execute('''
      CREATE INDEX idx_upload_status ON evidence(upload_status)
    ''');
  }

  // ---------------------------------------------------------------------------
  // INSERT — accepts a raw Map (matches how EvidenceService calls it)
  // ---------------------------------------------------------------------------
  Future<int> insertEvidence(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('evidence', data);
    print('✅ Evidence saved to local DB: ID=$id');
    return id;
  }

  // ---------------------------------------------------------------------------
  // UPDATE — partial update by ID (only the keys present in [updates] are written)
  // ---------------------------------------------------------------------------
  Future<int> updateEvidence(int id, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'evidence',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // QUERIES — return raw Maps so EvidenceService can index them directly.
  //           Use Evidence.fromMap() at the call site when you need the object.
  // ---------------------------------------------------------------------------

  /// All evidence, newest first
  Future<List<Map<String, dynamic>>> getAllEvidence() async {
    final db = await database;
    return await db.query(
      'evidence',
      orderBy: 'created_at DESC',
    );
  }

  /// Only rows still waiting to upload — oldest first so we drain in order
  Future<List<Map<String, dynamic>>> getPendingEvidence() async {
    final db = await database;
    final result = await db.query(
      'evidence',
      where: 'upload_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    print('📋 Found ${result.length} pending evidence in local DB');
    return result;
  }

  /// Single row by local ID
  Future<Map<String, dynamic>?> getEvidenceById(int id) async {
    final db = await database;
    final result = await db.query(
      'evidence',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ---------------------------------------------------------------------------
  // CONVENIENCE — higher-level helpers kept for any UI code that wants objects
  // ---------------------------------------------------------------------------

  /// Mark a single row as uploaded in one call
  Future<void> markAsUploaded(int id, String fileUrl) async {
    await updateEvidence(id, {
      'upload_status': 'uploaded',
      'file_url': fileUrl,
      'uploaded_at': DateTime.now().toIso8601String(),
    });
    print('✅ Evidence $id marked as uploaded in local DB');
  }

  /// Delete a single row
  Future<int> deleteEvidence(int id) async {
    final db = await database;
    return await db.delete(
      'evidence',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Nuke everything (dev / reset only)
  Future<void> clearAllEvidence() async {
    final db = await database;
    await db.delete('evidence');
    print('🗑️ All evidence cleared from local DB');
  }

  /// Close the connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}