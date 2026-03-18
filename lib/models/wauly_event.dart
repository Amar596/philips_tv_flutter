
enum EventType {
  started,
  alive,
  heartbeat,
  foregrounded,
  backgrounded,
  stopped,
  crash,
  test,
  unknown
}

class WaulyEvent {
  final String rawMessage;
  final DateTime receivedAt;
  final EventType type;

  WaulyEvent({
    required this.rawMessage,
    required this.receivedAt,
    required this.type,
  });

  factory WaulyEvent.fromMessage(String message) {
    return WaulyEvent(
      rawMessage: message,
      receivedAt: DateTime.now(),
      type: _parseType(message),
    );
  }

  static EventType _parseType(String message) {
    final m = message.toUpperCase();
    if (m.contains('STARTED')) return EventType.started;
    if (m.contains('ALIVE')) return EventType.alive;
    if (m.contains('RUNNING')) return EventType.heartbeat;
    if (m.contains('FOREGROUND') || m.contains('RESUMED'))
      return EventType.foregrounded;
    if (m.contains('BACKGROUND') || m.contains('PAUSED'))
      return EventType.backgrounded;
    if (m.contains('STOPPED') || m.contains('DESTROY'))
      return EventType.stopped;
    if (m.contains('CRASH') || m.contains('EXCEPTION') || m.contains('ERROR'))
      return EventType.crash;
    if (m.contains('TEST')) return EventType.test;

    return EventType.unknown;
  }

  String get timeString {
    final t = receivedAt;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  String get displayType {
    switch (type) {
      case EventType.started:
        return '🚀 STARTED';
      case EventType.alive:
        return '💓 ALIVE';
      case EventType.heartbeat:
        return '💓 RUNNING';
      case EventType.foregrounded:
        return '📱 FOREGROUND';
      case EventType.backgrounded:
        return '⏸️ BACKGROUND';
      case EventType.stopped:
        return '⏹️ STOPPED';
      case EventType.crash:
        return '💥 CRASH';
      case EventType.test:
        return '🧪 TEST';
      case EventType.unknown:
        return '❓ UNKNOWN';
    }
  }
}
