import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/notification_service.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const BookingScreen({super.key, required this.event});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _seatsRequested = 1;
  bool _isLoading = false;

  late double _pricePerSeat;
  late int _availableSeats;

  @override
  void initState() {
    super.initState();
    _pricePerSeat = (widget.event['price'] as num).toDouble();
    _availableSeats = widget.event['available_seats'] as int;
  }

  double get _totalPrice => _seatsRequested * _pricePerSeat;

  Future<void> _confirmBooking() async {
    if (_seatsRequested < 1 || _seatsRequested > _availableSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid number of seats')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final eventResponse = await supabase
          .from('events')
          .select('available_seats')
          .eq('id', widget.event['id'])
          .single();

      final currentAvailable = eventResponse['available_seats'] as int;
      if (currentAvailable < _seatsRequested) {
        throw Exception('Not enough seats available anymore');
      }

      await supabase.from('bookings').insert({
        'event_id': widget.event['id'],
        'user_id': userId,
        'seats_booked': _seatsRequested,
        'status': 'confirmed',
      });

      await supabase
          .from('events')
          .update({'available_seats': currentAvailable - _seatsRequested})
          .eq('id', widget.event['id']);

      await NotificationService.showNotification(
        title: 'Booking Confirmed',
        body: 'Your booking for ${widget.event['name']} is confirmed.',
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (error) {
      debugPrint('Booking Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Booking Confirmed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${widget.event['name']}'),
            Text('Seats: $_seatsRequested'),
            Text('Total Price: \$${_totalPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text('You can find your ticket in the My Bookings tab.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Pop BookingScreen
              Navigator.of(context).pop(); // Pop EventDetailsScreen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime eventDate = DateTime.parse(widget.event['event_date']);
    final String formattedDate = DateFormat('MMM d, yyyy · h:mm a').format(eventDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Book: ${widget.event['name']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event['name'],
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(widget.event['location'], style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Price per seat:'),
                        Text(
                          _pricePerSeat == 0 ? 'Free' : '\$${_pricePerSeat.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Select Seats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _isLoading || _seatsRequested <= 1
                      ? null
                      : () => setState(() => _seatsRequested--),
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '$_seatsRequested',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _isLoading || _seatsRequested >= _availableSeats
                      ? null
                      : () => setState(() => _seatsRequested++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$_availableSeats seats available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(height: 48),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Price',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _totalPrice == 0 ? 'Free' : '\$${_totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _confirmBooking,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Confirm Booking',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
