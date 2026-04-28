import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import '../models/movie.dart';
import 'cast_screen.dart';
import '../widgets/mode_toggle.dart';

class MovieDetailScreen extends StatefulWidget {
  final String movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  late Future<MovieDetailItem?> _movieFuture;

  @override
  void initState() {
    super.initState();
    _movieFuture = apiService.getMovieDetail(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MovieDetailItem?>(
      future: _movieFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final movie = snapshot.data;
        if (movie == null) return const Scaffold(body: Center(child: Text("Movie not found")));

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                actions: const [ModeToggle()],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(movie.title, style: const TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.grey[900]!, Colors.black],
                      )
                    ),
                    child: const Center(child: Icon(Icons.local_movies_rounded, size: 100, color: Colors.white24)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: Colors.white70),
                              const SizedBox(width: 8),
                              Text('${movie.releaseYear}', style: const TextStyle(fontSize: 18, color: Colors.white70)),
                            ],
                          ),
                          Row(
                             children: [
                              const Icon(Icons.star, color: Colors.amber, size: 22),
                              const SizedBox(width: 8),
                              Text('${movie.rating}/10', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                             ],
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        children: movie.genres.map((g) => Chip(
                          label: Text(g, style: const TextStyle(fontWeight: FontWeight.w600)),
                          backgroundColor: Colors.white12,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        )).toList(),
                      ),
                      const SizedBox(height: 32),
                      const Text("Director", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(movie.director, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 32),
                      const Text("Overview", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 12),
                      Text(movie.description, style: const TextStyle(fontSize: 16, height: 1.6, letterSpacing: 0.5)),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CastScreen(movieId: movie.id)),
                            );
                          },
                          child: const Text("View Full Cast & Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
