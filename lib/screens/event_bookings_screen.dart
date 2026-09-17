import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class EventBookingsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventBookingsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventBookingsScreen> createState() => _EventBookingsScreenState();
}

class _EventBookingsScreenState extends State<EventBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  int _totalSeatsBooked = 0;
  int _confirmedBookingsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('bookings')
          .select('*, profiles(full_name, phone)')
          .eq('event_id', widget.eventId)
          .order('created_at', ascending: true);

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);

      int seats = 0;
      int count = 0;
      for (var b in data) {
        if (b['status'] == 'confirmed') {
          seats += b['seats_booked'] as int;
          count++;
        }
      }

      if (mounted) {
        setState(() {
          _bookings = data;
          _totalSeatsBooked = seats;
          _confirmedBookingsCount = count;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error fetching event bookings: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookings: ${widget.eventName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem(
                        label: 'Confirmed',
                        value: '$_confirmedBookingsCount',
                      ),
                      _SummaryItem(
                        label: 'Seats Booked',
                        value: '$_totalSeatsBooked',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchBookings,
                    child: _bookings.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline,
                                        size: 64, color: Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    const Text('No bookings yet',
                                        style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _bookings.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final booking = _bookings[index];
                              final profile = booking['profiles']
                                  as Map<String, dynamic>?;
                              final date =
                                  DateTime.parse(booking['created_at']);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  profile?['full_name'] ?? 'Unknown User',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (profile?['phone'] != null &&
                                        profile!['phone'].toString().isNotEmpty)
                                      Text('Phone: ${profile['phone']}'),
                                    Text(
                                        'Booked on: ${DateFormat('MMM d, h:mm a').format(date)}'),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${booking['seats_booked']} Seats',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    _StatusBadge(status: booking['status']),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status == 'confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isConfirmed ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isConfirmed ? Colors.green[200]! : Colors.grey[300]!,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isConfirmed ? Colors.green[700] : Colors.grey[600],
        ),
      ),
    );
  }
}
