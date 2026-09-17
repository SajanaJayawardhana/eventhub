import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/notification_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _pastBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('bookings')
          .select('*, events(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> bookings =
          List<Map<String, dynamic>>.from(response);

      final now = DateTime.now();
      final List<Map<String, dynamic>> upcoming = [];
      final List<Map<String, dynamic>> past = [];

      for (var booking in bookings) {
        final event = booking['events'] as Map<String, dynamic>?;
        if (event == null) continue;

        final eventDate = DateTime.parse(event['event_date']);
        final isConfirmed = booking['status'] == 'confirmed';

        if (isConfirmed && eventDate.isAfter(now)) {
          upcoming.add(booking);
        } else {
          past.add(booking);
        }
      }

      if (mounted) {
        setState(() {
          _upcomingBookings = upcoming;
          _pastBookings = past;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error fetching bookings: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final int seatsBooked = booking['seats_booked'];
      final String eventId = booking['event_id'];

      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', booking['id']);

      final eventResponse = await supabase
          .from('events')
          .select('available_seats')
          .eq('id', eventId)
          .single();

      final currentAvailable = eventResponse['available_seats'] as int;
      await supabase
          .from('events')
          .update({'available_seats': currentAvailable + seatsBooked})
          .eq('id', eventId);

      await NotificationService.showNotification(
        title: 'Booking Cancelled',
        body: 'Your booking for ${booking['events']['name']} has been cancelled.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchBookings();
      }
    } catch (error) {
      debugPrint('Cancel Booking Error: $error');
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _BookingsList(
                bookings: _upcomingBookings,
                isLoading: _isLoading,
                onRefresh: _fetchBookings,
                onCancel: _cancelBooking,
                emptyMessage: 'No upcoming bookings',
                emptyIcon: Icons.calendar_today,
              ),
              _BookingsList(
                bookings: _pastBookings,
                isLoading: _isLoading,
                onRefresh: _fetchBookings,
                onCancel: null,
                emptyMessage: 'No past bookings',
                emptyIcon: Icons.history,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>)? onCancel;
  final String emptyMessage;
  final IconData emptyIcon;

  const _BookingsList({
    required this.bookings,
    required this.isLoading,
    required this.onRefresh,
    required this.onCancel,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 100),
            Center(
              child: Column(
                children: [
                  Icon(emptyIcon, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          final event = booking['events'] as Map<String, dynamic>?;
          if (event == null) return const SizedBox.shrink();

          final eventDate = DateTime.parse(event['event_date']);
          final formattedDate =
              DateFormat('MMM d, yyyy · h:mm a').format(eventDate);
          final isCancelled = booking['status'] == 'cancelled';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event['name'],
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      _StatusBadge(status: booking['status']),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(formattedDate,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(event['location'],
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${booking['seats_booked']} seats booked',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (onCancel != null && !isCancelled)
                        TextButton.icon(
                          onPressed: () => onCancel!(booking),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Cancel Booking'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
