import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import '../models/movie.dart';
import 'movie_detail.dart';
import '../widgets/app_drawer.dart';
import '../widgets/mode_toggle.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  late Future<List<MovieListItem>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _moviesFuture = apiService.getMovies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1.2)),
        centerTitle: true,
        actions: const [ModeToggle()],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<MovieListItem>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final movies = snapshot.data ?? [];
          if (movies.isEmpty) {
            return const Center(
              child: Text(
                'No movies found.\nMake sure the backend is running and seeded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailScreen(movieId: movie.id),
                      ),
                    );
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 90,
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(12),
                              image: movie.imageUrl != null && movie.imageUrl!.isNotEmpty
                                  ? DecorationImage(image: NetworkImage(movie.imageUrl!), fit: BoxFit.cover)
                                  : null,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4))
                              ]
                            ),
                            child: movie.imageUrl == null || movie.imageUrl!.isEmpty
                                ? const Icon(Icons.movie_creation_outlined, size: 40, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  movie.title,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month, color: Colors.white70, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${movie.releaseYear}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                    const SizedBox(width: 4),
                                    Text('${movie.rating}/10', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
