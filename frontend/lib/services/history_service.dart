import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.phrase,
    required this.createdAt,
  });

  final String id;
  final String phrase;
  final DateTime? createdAt;

  factory HistoryEntry.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];

    return HistoryEntry(
      id: doc.id,
      phrase: (data['phrase'] ?? '').toString(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class HistoryService {
  HistoryService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _historyCollection(
      String userId) {
    return _firestore.collection('users').doc(userId).collection('history');
  }

  static Future<void> savePhrase(String userId, String phrase) async {
    final normalizedPhrase = phrase.trim();
    if (userId.isEmpty || normalizedPhrase.isEmpty) return;

    await _historyCollection(userId).add({
      'phrase': normalizedPhrase,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<HistoryEntry>> streamHistory(String userId) {
    if (userId.isEmpty) return const Stream<List<HistoryEntry>>.empty();

    return _historyCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(HistoryEntry.fromSnapshot)
            .where((entry) => entry.phrase.isNotEmpty)
            .toList());
  }

  static Future<void> deleteEntry(String userId, String entryId) async {
    if (userId.isEmpty || entryId.isEmpty) return;
    await _historyCollection(userId).doc(entryId).delete();
  }
}
