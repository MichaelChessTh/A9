import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUid => _auth.currentUser!.uid;

  Future<void> saveCallLog({
    required String callID,
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    required String
    status, // 'Missed', 'Completed', 'Declined', 'Outgoing', 'Incoming'
  }) async {
    // Save for caller
    await _firestore
        .collection('Users')
        .doc(callerId)
        .collection('CallLogs')
        .doc(callID)
        .set({
          'callID': callID,
          'callerId': callerId,
          'callerName': callerName,
          'calleeId': calleeId,
          'calleeName': calleeName,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    // Save for callee
    await _firestore
        .collection('Users')
        .doc(calleeId)
        .collection('CallLogs')
        .doc(callID)
        .set({
          'callID': callID,
          'callerId': callerId,
          'callerName': callerName,
          'calleeId': calleeId,
          'calleeName': calleeName,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> getCallLogs() {
    return _firestore
        .collection('Users')
        .doc(_currentUid)
        .collection('CallLogs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> clearCallLogs() async {
    var snapshot =
        await _firestore
            .collection('Users')
            .doc(_currentUid)
            .collection('CallLogs')
            .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
