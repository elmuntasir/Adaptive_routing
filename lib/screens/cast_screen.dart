import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import '../models/movie.dart';

class CastScreen extends StatefulWidget {
  final String movieId;
  const CastScreen({super.key, required this.movieId});

  @override
  State<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends State<CastScreen> {
  late Future<MovieFullItem?> _fullMovieFuture;

  @override
  void initState() {
    super.initState();
    _fullMovieFuture = apiService.getMovieFull(widget.movieId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MovieFullItem?>(
      future: _fullMovieFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        final fullMovie = snapshot.data;
        if (fullMovie == null) return const Scaffold(body: Center(child: Text("Movie details not found")));

        return Scaffold(
          appBar: AppBar(title: const Text("Cast & Reviews", style: TextStyle(fontWeight: FontWeight.bold))),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              const Text("Top Cast", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 20),
              ...fullMovie.cast.map((actor) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white70, size: 30),
                  ),
                  title: Text(actor.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Text(actor.bio, style: const TextStyle(color: Colors.white60, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              )),
              const SizedBox(height: 32),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 32),
              const Text("User Reviews", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 20),
              ...fullMovie.reviews.map((review) => Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_circle, color: Colors.white54, size: 28),
                            const SizedBox(width: 8),
                            Text(review.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${review.score}/10', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(review.content, style: const TextStyle(height: 1.5, fontSize: 15, color: Colors.white70)),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}
