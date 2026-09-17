import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';

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

      // 1. Double check availability right before booking (Simple approach)
      final eventResponse = await supabase
          .from('events')
          .select('available_seats')
          .eq('id', widget.event['id'])
          .single();

      final currentAvailable = eventResponse['available_seats'] as int;
      if (currentAvailable < _seatsRequested) {
        throw Exception('Not enough seats available anymore');
      }

      // 2. Insert Booking
      await supabase.from('bookings').insert({
        'event_id': widget.event['id'],
        'user_id': userId,
        'seats_booked': _seatsRequested,
        'status': 'confirmed',
      });

      // 3. Update Event Seats
      await supabase
          .from('events')
          .update({'available_seats': currentAvailable - _seatsRequested})
          .eq('id', widget.event['id']);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${error.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
              // Navigate back to BrowseEventsScreen (pop twice)
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
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _seatsRequested > 1
                      ? () => setState(() => _seatsRequested--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '$_seatsRequested',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _seatsRequested < _availableSeats
                      ? () => setState(() => _seatsRequested++)
                      : null,
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
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
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
