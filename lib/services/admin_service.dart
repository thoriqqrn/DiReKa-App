import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_constants.dart';
import '../models/disease_type.dart';
import '../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection(AppConstants.colUsers);

  /// Total jumlah user terdaftar
  Future<int> getTotalUsers() async {
    final snapshot = await _users.count().get();
    return snapshot.count ?? 0;
  }

  /// Jumlah user per jenis penyakit
  Future<Map<DiseaseType, int>> getUsersByDisease() async {
    final result = <DiseaseType, int>{};
    for (final disease in DiseaseType.values) {
      final snapshot = await _users
          .where('diseaseType', isEqualTo: disease.value)
          .count()
          .get();
      result[disease] = snapshot.count ?? 0;
    }
    return result;
  }

  /// Ambil semua user (untuk tabel)
  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _users.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  /// Stream realtime jumlah user
  Stream<int> userCountStream() {
    return _users.snapshots().map((snap) => snap.docs.length);
  }
}
