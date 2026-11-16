import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/product.dart';

class ProductRepo {
  ProductRepo._();
  static final instance = ProductRepo._();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get _hasFirebase => Firebase.apps.isNotEmpty;

  // Todos (collectionGroup)
  Stream<List<Product>> streamAll({int? limit}) {
    if (!_hasFirebase) {
      return Stream.value(const <Product>[]);
    }
    Query<Map<String, dynamic>> q = _db.collectionGroup('items');
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map((s) => s.docs.map(Product.fromDoc).toList());
  }

  // Por categoria
  Stream<List<Product>> streamByCategory(String categoryId, {int? limit}) {
    if (!_hasFirebase) {
      return Stream.value(const <Product>[]);
    }
    Query<Map<String, dynamic>> q =
        _db.collection('Products').doc(categoryId).collection('items');
    if (limit != null) q = q.limit(limit);
    return q.snapshots().map((s) => s.docs.map(Product.fromDoc).toList());
  }

  // Um item específico
  Future<Product> getOne(String categoryId, String pid) async {
    if (!_hasFirebase) {
      return Product(
        id: pid,
        title: '',
        priceCents: 0,
        images: const [],
        sizes: const [],
        description: '',
        categoryId: categoryId,
        exists: false,
      );
    }
    final doc = await _db
        .collection('Products')
        .doc(categoryId)
        .collection('items')
        .doc(pid)
        .get();
    return Product.fromDoc(doc);
  }
}
