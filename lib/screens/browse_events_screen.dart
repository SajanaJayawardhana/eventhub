import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/favorites_service.dart';
import 'event_details_screen.dart';

class BrowseEventsScreen extends StatefulWidget {
  const BrowseEventsScreen({super.key});

  @override
  State<BrowseEventsScreen> createState() => _BrowseEventsScreenState();
}

class _BrowseEventsScreenState extends State<BrowseEventsScreen> {
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  List<String> _categories = ['All'];
  Set<String> _favoriteIds = {};
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showOnlyFavorites = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchEvents(),
      _loadFavorites(),
    ]);
    setState(() => _isLoading = false);
    _filterEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final data = await supabase
          .from('events')
          .select()
          .order('event_date', ascending: true);

      final List<Map<String, dynamic>> events =
          List<Map<String, dynamic>>.from(data);

      // Extract unique categories
      final Set<String> categorySet = {'All'};
      for (var event in events) {
        if (event['category'] != null) {
          categorySet.add(event['category'] as String);
        }
      }

      _allEvents = events;
      _categories = categorySet.toList()..sort();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching events: $error')),
        );
      }
    }
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoritesService.getFavoriteIds();
    setState(() {
      _favoriteIds = favorites;
    });
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _allEvents.where((event) {
        final matchesCategory = _selectedCategory == 'All' ||
            event['category'] == _selectedCategory;
        final matchesSearch = event['name']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final matchesFavorites = !_showOnlyFavorites || _favoriteIds.contains(event['id']);

        return matchesCategory && matchesSearch && matchesFavorites;
      }).toList();
    });
  }

  Future<void> _refreshFavorites() async {
    await _loadFavorites();
    _filterEvents();
  }

  Future<void> _toggleFavorite(String eventId) async {
    await FavoritesService.toggleFavorite(eventId);
    await _refreshFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) {
              _searchQuery = value;
              _filterEvents();
            },
            decoration: InputDecoration(
              hintText: 'Search events...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 16),
                      SizedBox(width: 4),
                      Text('Favorites'),
                    ],
                  ),
                  selected: _showOnlyFavorites,
                  onSelected: (selected) {
                    setState(() {
                      _showOnlyFavorites = selected;
                      _filterEvents();
                    });
                  },
                ),
              ),
              const VerticalDivider(indent: 16, endIndent: 16),
              ..._categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _filterEvents();
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEvents.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(child: Text('No events found')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = _filteredEvents[index];
                          final eventId = event['id'];
                          return _EventCard(
                            event: event,
                            isFavorite: _favoriteIds.contains(eventId),
                            onFavoriteToggle: () => _toggleFavorite(eventId),
                            onRefreshFavorites: _refreshFavorites,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onRefreshFavorites;

  const _EventCard({
    required this.event,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onRefreshFavorites,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime eventDate = DateTime.parse(event['event_date']);
    final String formattedDate =
        DateFormat('MMM d, yyyy · h:mm a').format(eventDate);
    final double price = (event['price'] as num).toDouble();
    final int availableSeats = event['available_seats'] as int;
    final String? imageUrl = event['image_url'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
          // Refresh screen state when coming back from details
          onRefreshFavorites();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image,
                          size: 64, color: Colors.grey),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: const Icon(Icons.event, size: 64, color: Colors.grey),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: onFavoriteToggle,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
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
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          event['category'] ?? 'General',
                          style: const TextStyle(fontSize: 12),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(formattedDate,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(event['location'],
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price == 0 ? 'Free' : '\$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        availableSeats == 0
                            ? 'Sold Out'
                            : '$availableSeats seats left',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (availableSeats < 5 || availableSeats == 0)
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
