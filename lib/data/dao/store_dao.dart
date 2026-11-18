import 'package:sqflite/sqflite.dart';
import '../models/store_model.dart';

class StoreDao {
  final Database database;

  StoreDao(this.database);

  Future<List<StoreModel>> searchStores(String query) async {
    final rows = await database.query(
      'stores',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );

    return rows.map(StoreModel.fromMap).toList();
  }

  Future<StoreModel?> getStoreById(int id) async {
    final rows = await database.query(
      'stores',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return StoreModel.fromMap(rows.first);
  }
}
