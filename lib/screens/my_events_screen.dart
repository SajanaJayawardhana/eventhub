import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'add_edit_event_screen.dart';
import 'event_bookings_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  List<Map<String, dynamic>> _myEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyEvents();
  }

  Future<void> _fetchMyEvents() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('events')
          .select()
          .eq('organizer_id', userId)
          .order('event_date', ascending: true);

      if (mounted) {
        setState(() {
          _myEvents = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error fetching my events: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
            'Are you sure you want to delete "${event['name']}"? This will also remove all bookings for this event.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.from('events').delete().eq('id', event['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
          _fetchMyEvents();
        }
      } catch (error) {
        debugPrint('Delete Event Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Something went wrong. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchMyEvents,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _myEvents.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_note, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text("You haven't created any events yet",
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myEvents.length,
                    itemBuilder: (context, index) {
                      final event = _myEvents[index];
                      final DateTime eventDate =
                          DateTime.parse(event['event_date']);
                      final String formattedDate =
                          DateFormat('MMM d, yyyy · h:mm a').format(eventDate);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['name'],
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(formattedDate,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.people,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${event['available_seats']} / ${event['total_seats']} seats available',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EventBookingsScreen(
                                            eventId: event['id'],
                                            eventName: event['name'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.list_alt),
                                    label: const Text('Bookings'),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AddEditEventScreen(
                                                  existingEvent: event),
                                        ),
                                      );
                                      if (result == true) _fetchMyEvents();
                                    },
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteEvent(event),
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditEventScreen(),
            ),
          );
          if (result == true) _fetchMyEvents();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
      ),
    );
  }
}
