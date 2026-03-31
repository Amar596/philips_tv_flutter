import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/events_database.dart';
import '../models/wauly_event.dart';
import '../services/native_event_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchdogScreen extends StatefulWidget {
  const WatchdogScreen({super.key});

  @override
  State<WatchdogScreen> createState() => _WatchdogScreenState();
}

class _WatchdogScreenState extends State<WatchdogScreen> {
  final List<WaulyEvent> _events = [];
  late final EventDatabase _db;
  //final EventDatabase _db = EventDatabase.instance;
  StreamSubscription<String>? _subscription;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  final Map<String, DateTime> _recentEvents = {};
  final Duration _dedupeWindow = const Duration(milliseconds: 500);
  final List<String> _ignoredPatterns = [
    'Event received (no message)',
    'Wauly Alive Event received',
    'WAULY ALIVE',
    'Unknown event',
  ];

  // Define platform here as a class member
  static const platform = MethodChannel('com.example.watchdog_app/test');

  // Summary counters
  int _aliveCount = 0;
  int _crashCount = 0;
  DateTime? _lastEventTime;

  @override
  void initState() {
    super.initState();
    _db = EventDatabase.instance;
    _loadSavedEvents();
    _startListening();
  }

  Future<void> _loadSavedEvents() async {
    try {
      await _db.database;
      final events = await _db.readAllEvents();
      setState(() {
        _events.clear();
        _events.addAll(events);
        _updateCounters();
      });
      debugPrint('✅ Loaded ${events.length} events from database');
    } catch (e) {
      debugPrint('❌ Error loading events: $e');
    }
  }

  void _updateCounters() {
    _aliveCount = _events.where((e) => e.type == EventType.alive).length;
    _crashCount = _events.where((e) => e.type == EventType.crash).length;
    _lastEventTime = _events.isNotEmpty ? _events.first.receivedAt : null;
  }

  // Future<void> _addEvent(WaulyEvent event) async {
  //   if (event.rawMessage.contains('Event received (no message)') ||
  //       event.rawMessage.contains('Wauly Alive Event received') ||
  //       event.rawMessage.contains('WAULY ALIVE')||
  //       event.rawMessage.contains('WAULY APP BACKGROUNDED')||
  //       event.rawMessage.contains('Unknown event')) {
  //     debugPrint('⏭️ Ignored unwanted event: ${event.rawMessage}');
  //     return; // Skip this event completely
  //   }

  //   // Check for duplicates
  //   final now = DateTime.now();
  //   final lastSeen = _recentEvents[event.rawMessage];

  //   if (lastSeen != null && now.difference(lastSeen) < _dedupeWindow) {
  //     debugPrint('⏭️ Duplicate event ignored: ${event.rawMessage}');
  //     return; // Skip duplicate
  //   }

  //   // Store this event
  //   _recentEvents[event.rawMessage] = now;

  //   // Clean up old entries
  //   if (_recentEvents.length > 100) {
  //     _recentEvents
  //         .removeWhere((key, value) => now.difference(value) > _dedupeWindow);
  //   }

  //   try {
  //     // Save to database first
  //     await _db.createEvent(event);

  //     // Then update UI
  //     setState(() {
  //       _events.insert(0, event);
  //       _updateCounters();
  //       if (_events.length > 500) {
  //         _events.removeLast(); // Remove oldest event
  //       }
  //     });

  //     debugPrint('✅ Event saved to database: ${event.rawMessage}');
  //   } catch (e) {
  //     debugPrint('❌ Error saving event: $e');
  //   }
  // }

  Future<void> _addEvent(WaulyEvent event) async {
  debugPrint('🔍 Processing event: ${event.rawMessage} (Type: ${event.type})');
  
  // Check if this is a test event - always show test events
  if (event.type == EventType.test) {
    debugPrint('✅ Test event detected - will display');
  }
  
  if (event.rawMessage.contains('Event received (no message)') ||
      event.rawMessage.contains('Wauly Alive Event received') ||
      event.rawMessage.contains('WAULY ALIVE')||
      event.rawMessage.contains('WAULY APP BACKGROUNDED')||
      event.rawMessage.contains('Unknown event')) {
    debugPrint('⏭️ Ignored unwanted event: ${event.rawMessage}');
    return; // Skip this event completely
  }

  // Check for duplicates
  final now = DateTime.now();
  final lastSeen = _recentEvents[event.rawMessage];

  if (lastSeen != null && now.difference(lastSeen) < _dedupeWindow) {
    debugPrint('⏭️ Duplicate event ignored: ${event.rawMessage}');
    return; // Skip duplicate
  }

  // Store this event
  _recentEvents[event.rawMessage] = now;

  // Clean up old entries
  if (_recentEvents.length > 100) {
    _recentEvents
        .removeWhere((key, value) => now.difference(value) > _dedupeWindow);
  }

  try {
    // Save to database first
    await _db.createEvent(event);
    debugPrint('💾 Event saved to DB: ${event.rawMessage}');

    // Then update UI
    setState(() {
      _events.insert(0, event);
      _updateCounters();
      if (_events.length > 500) {
        _events.removeLast(); // Remove oldest event
      }
    });

    debugPrint('✅ UI updated, total events: ${_events.length}');
    debugPrint('✅ Event saved to database: ${event.rawMessage}');
  } catch (e) {
    debugPrint('❌ Error saving event: $e');
  }
  }
  
  void _startListening() {
    _subscription = NativeEventService.eventStream.listen(
      (message) {
        // Skip if message contains any ignored pattern
        if (_ignoredPatterns.any((pattern) => message.contains(pattern))) {
          debugPrint('⏭️ Filtered out: $message');
          return;
        }
        final event = WaulyEvent.fromMessage(message);
        _addEvent(event); // This now handles both saving and UI update

        if (_autoScroll && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      },
      onError: (error) {
        debugPrint('EventChannel error: $error');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    //_db.close();
    super.dispose();
  }

  Future<void> _clearEvents() async {
    try {
      await _db.deleteAll(); // Clear database
      setState(() {
        _events.clear();
        _aliveCount = 0;
        _crashCount = 0;
        _lastEventTime = null;
      });
      debugPrint('✅ All events cleared');
    } catch (e) {
      debugPrint('❌ Error clearing events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Row(
          children: [
            _StatusDot(isActive: _events.isNotEmpty),
            const SizedBox(width: 8),
            const Text(
              'Wauly Watchdog',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Clear events',
            onPressed: _events.isEmpty ? null : _clearEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryBar(
            totalEvents: _events.length,
            aliveCount: _aliveCount,
            crashCount: _crashCount,
            lastEventTime: _lastEventTime,
          ),
          const Divider(color: Color(0xFF30363D), height: 1),
          Expanded(
            child: _events.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _events.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFF21262D), height: 1),
                    itemBuilder: (context, index) {
                      return _EventTile(event: _events[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendTestEvent,
        child: const Icon(Icons.play_arrow),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  // Add this method
  void _sendTestEvent() async {
    try {
      // Try to send through native channel
      final String result = await platform.invokeMethod('sendTestBroadcast');
      debugPrint('✅ Test broadcast sent: $result');

      // Show a snackbar for feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test broadcast sent!'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to send test broadcast: ${e.message}');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.message}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );

      // Fallback to local test event
      setState(() {
        final testEvent = WaulyEvent(
          rawMessage: '⚠️ LOCAL TEST (native channel failed)',
          receivedAt: DateTime.now(),
          type: EventType.test,
        );
        _events.insert(0, testEvent);
        _lastEventTime = testEvent.receivedAt;

        if (_events.length > 500) _events.removeLast();
      });
    }
  }
}

// ─── Summary Bar ────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int totalEvents;
  final int aliveCount;
  final int crashCount;
  final DateTime? lastEventTime;

  const _SummaryBar({
    required this.totalEvents,
    required this.aliveCount,
    required this.crashCount,
    required this.lastEventTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _StatChip(
              label: 'Total', value: '$totalEvents', color: Colors.blueAccent),
          const SizedBox(width: 10),
          // _StatChip(
          //     label: 'Alive', value: '$aliveCount', color: Colors.greenAccent),
          // const SizedBox(width: 10),
          // _StatChip(
          //     label: 'Crashes', value: '$crashCount', color: Colors.redAccent),
          const Spacer(),
          if (lastEventTime != null)
            Text(
              'Last Active Time : ${_fmt(lastEventTime!)}',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 15),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextSpan(
              text: label,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Event Tile ──────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final WaulyEvent event;

  const _EventTile({required this.event});

    // Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final config = _eventConfig(event.type);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: config.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: config.color.withOpacity(0.6), blurRadius: 8),
          ],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              event.rawMessage.length > 40
                  ? '${event.rawMessage.substring(0, 40)}...'
                  : event.rawMessage,
              style: TextStyle(
                color: config.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: config.color.withOpacity(0.3)),
            ),
            child: Text(
              event.timeString,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
        Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          event.displayType,
          style: TextStyle(
            color: config.color.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          _formatDate(event.receivedAt),
          style: const TextStyle(
            color: Color(0xFF8B949E),
            fontSize: 12,
          ),
        ),
      ),
        ],
    ),
    );
  }

  _EventConfig _eventConfig(EventType type) {
    switch (type) {
      case EventType.started:
        return _EventConfig(
            Colors.cyanAccent, 'STARTED', Colors.cyanAccent.shade100);
      case EventType.alive:
        return _EventConfig(
            Colors.greenAccent, 'ALIVE', const Color(0xFFCCFFCC));
      case EventType.heartbeat:
        return _EventConfig(
            Colors.lightGreenAccent, 'HEARTBEAT', const Color(0xFFE0FFE0));
      case EventType.foregrounded: // Add this case
        return _EventConfig(
            Colors.blueAccent, 'FOREGROUND', const Color(0xFFCCE5FF));
      case EventType.backgrounded:
        return _EventConfig(
            Colors.orangeAccent, 'BACKGROUND', const Color(0xFFFFECCC));
      case EventType.stopped:
        return _EventConfig(Colors.orange, 'STOPPED', const Color(0xFFFFE0B2));
      case EventType.crash:
        return _EventConfig(Colors.redAccent, 'CRASH', const Color(0xFFFFCDD2));
      case EventType.test:
        return _EventConfig(
            Colors.purpleAccent, 'TEST', const Color(0xFFE8D5FF));
      case EventType.unknown:
        return _EventConfig(const Color(0xFF8B949E), 'EVENT', Colors.white70);
    }
  }
}

class _EventConfig {
  final Color color;
  final String label;
  final Color textColor;
  _EventConfig(this.color, this.label, this.textColor);
}

// ─── Status Dot ──────────────────────────────────────────────────────────────

class _StatusDot extends StatefulWidget {
  final bool isActive;
  const _StatusDot({required this.isActive});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose(); // Only dispose the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.isActive ? Colors.greenAccent : Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'Listening for events...',
            style:
                TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Events from the Wauly sender app\nwill appear here in real-time',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
