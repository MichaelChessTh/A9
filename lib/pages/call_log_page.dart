import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:googlechat/services/auth/auth_service.dart';
import 'package:googlechat/services/call/call_log_service.dart';
import 'package:intl/intl.dart';

class CallLogPage extends StatelessWidget {
  CallLogPage({super.key});

  final CallLogService _callLogService = CallLogService();
  final String _currentUid = AuthService().getCurrentUser()!.uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Call Log'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _showClearConfirmation(context),
            tooltip: 'Clear call history',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _callLogService.getCallLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading call logs'));
          }

          final logs = snapshot.data?.docs ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.call_missed_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No call history',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: logs.length,
            separatorBuilder:
                (context, index) => Divider(
                  height: 1,
                  indent: 72,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;

              final callerId = data['callerId'] as String;
              final status = data['status'] as String;
              final timestamp = data['timestamp'] as Timestamp?;

              final isOutgoing = callerId == _currentUid;
              final otherParticipantName =
                  isOutgoing ? data['calleeName'] : data['callerName'];

              // Define icon and color based on status and direction
              IconData statusIcon;
              Color statusColor;

              if (status == 'Missed') {
                statusIcon =
                    isOutgoing
                        ? Icons.call_made_rounded
                        : Icons.call_missed_rounded;
                statusColor = Colors.red.shade400;
              } else if (status == 'Declined') {
                statusIcon =
                    isOutgoing
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded;
                statusColor = Colors.red.shade400;
              } else {
                // Incoming or Accepted
                statusIcon =
                    isOutgoing
                        ? Icons.call_made_rounded
                        : Icons.call_received_rounded;
                statusColor = Colors.green.shade500;
              }

              // format time
              String timeString = '';
              if (timestamp != null) {
                final date = timestamp.toDate();
                if (DateTime.now().difference(date).inDays > 0) {
                  timeString = DateFormat('MMM d, h:mm a').format(date);
                } else {
                  timeString = DateFormat('h:mm a').format(date);
                }
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      otherParticipantName.toString().isNotEmpty
                          ? otherParticipantName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  otherParticipantName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      '$status • $timeString',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.call_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    // Navigate to chat or directly call
                    // We'll just pop for now, they can call from chat
                    Navigator.pop(context);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Call Log'),
            content: const Text(
              'Are you sure you want to delete all call history? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  _callLogService.clearCallLogs();
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }
}
