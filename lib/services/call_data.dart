import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { ringing, ongoing, ended, missed }
enum CallType { voice, video }

class CallData {
  final String callId;
  final String callerId;
  final String receiverId;
  final String callerName;
  final String receiverName;
  final CallType callType;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  CallData({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.callerName,
    required this.receiverName,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
  });

  factory CallData.fromMap(Map<String, dynamic> map) {
    return CallData(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      callerName: map['callerName'] ?? '',
      receiverName: map['receiverName'] ?? '',
      callType: _parseCallType(map['callType']),
      status: _parseStatus(map['status']),
      startedAt: _toDateTime(map['startedAt']),
      answeredAt: _toNullableDateTime(map['answeredAt']),
      endedAt: _toNullableDateTime(map['endedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'receiverId': receiverId,
      'callerName': callerName,
      'receiverName': receiverName,
      'callType': callType.name,
      'status': status.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'participants': [callerId, receiverId],
    };
  }

  static CallStatus _parseStatus(String? value) {
    return CallStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CallStatus.ringing,
    );
  }

  static CallType _parseCallType(String? value) {
    return CallType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CallType.voice,
    );
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
