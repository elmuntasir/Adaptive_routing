import random
from app import app
from models import db, Movie, Actor, Genre, Review

REAL_MOVIES = [
    {"title": "The Shawshank Redemption", "year": 1994, "rating": 9.3, "director": "Frank Darabont",
     "description": "Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMDAyY2FhYjctNDc5OS00MDNlLThiMGUtY2UxYWVkNGY2ZjljXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "The Godfather", "year": 1972, "rating": 9.2, "director": "Francis Ford Coppola",
     "description": "The aging patriarch of an organized crime dynasty transfers control of his clandestine empire to his reluctant youngest son.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BYTJkNGQyZDgtZDQ0NC00MDM0LWEzZWQtYzUzZDEwMDljZWNjXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "The Dark Knight", "year": 2008, "rating": 9.0, "director": "Christopher Nolan",
     "description": "When the menace known as the Joker wreaks havoc on Gotham, Batman must accept one of the greatest psychological and physical tests.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMTMxNTMwODM0NF5BMl5BanBnXkFtZTcwODAyMTk2Mw@@._V1_SX300.jpg"},
    {"title": "Inception", "year": 2010, "rating": 8.8, "director": "Christopher Nolan",
     "description": "A thief who steals corporate secrets through dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMjAxMzY3NjcxNF5BMl5BanBnXkFtZTcwNTI5OTM0Mw@@._V1_SX300.jpg"},
    {"title": "Pulp Fiction", "year": 1994, "rating": 8.9, "director": "Quentin Tarantino",
     "description": "The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine in four tales of violence and redemption.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BYTViYTE3ZGQtNDBlMC00ZTAyLTkyODMtZGRiZDg0MjA2YThkXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Forrest Gump", "year": 1994, "rating": 8.8, "director": "Robert Zemeckis",
     "description": "The presidencies of Kennedy and Johnson, the Vietnam War, and other historical events unfold from the perspective of an Alabama man.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BNDYwNzVjMTYtZmU5YzQtYTY2ZS1hMWNkLTg0MTAtNjQzZGI4OWQxNjQ5XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "The Matrix", "year": 1999, "rating": 8.7, "director": "Lana Wachowski",
     "description": "When a beautiful stranger leads computer hacker Neo to a forbidding underworld, he discovers the shocking truth.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BN2NmN2VhMTQtMDNiOS00NDlhLTliMjgtODE2ZTY0ODQyNDL0XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Interstellar", "year": 2014, "rating": 8.7, "director": "Christopher Nolan",
     "description": "A team of explorers travel through a wormhole in space in an attempt to ensure humanity's survival.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BYzdjMDAxZGItMjI2My00ODA1LTlkNzItOWFjMDU5ZDJlYWY3XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Fight Club", "year": 1999, "rating": 8.8, "director": "David Fincher",
     "description": "An insomniac office worker and a devil-may-care soap maker form an underground fight club that evolves into much more.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BOTgyOGQ1NDItNGU3Ny00MjU3LTg2YWEtNmEyYjBiMjI1Y2M5XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Goodfellas", "year": 1990, "rating": 8.7, "director": "Martin Scorsese",
     "description": "The story of Henry Hill and his life in the mob, covering his relationship with his wife Karen Hill and his mob partners.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BN2E5NzI2ZGMtY2VjNi00YTRjLWI1MDUtZGY5OWU1MWJjZjRjXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "The Lord of the Rings: The Return of the King", "year": 2003, "rating": 9.0, "director": "Peter Jackson",
     "description": "Gandalf and Aragorn lead the World of Men against Sauron's army to draw his gaze from Frodo and Sam as they approach Mount Doom.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMTZkMjBjNWMtZGI5OC00MGU0LTk4ZTItODg2NWM3NTVmNWQ4XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Schindler's List", "year": 1993, "rating": 9.0, "director": "Steven Spielberg",
     "description": "In German-occupied Poland during World War II, industrialist Oskar Schindler gradually becomes concerned for his Jewish workforce.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BNjM1ZDQxYWUtMzQyZS00MTE1LWJmZGYtNGUyNTdlYjM3ZmVmXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Gladiator", "year": 2000, "rating": 8.5, "director": "Ridley Scott",
     "description": "A former Roman General sets out to exact vengeance against the corrupt emperor who murdered his family and sent him into slavery.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BYWQ4YmNjYjEtOWE1Zi00Y2U4LWI4NTAtMTU0MjkxNWQ1ZmJiXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "The Prestige", "year": 2006, "rating": 8.5, "director": "Christopher Nolan",
     "description": "After a tragic accident, two stage magicians in 1890s London engage in a battle to create the ultimate illusion.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMjA4NDI0MTIxNF5BMl5BanBnXkFtZTYwNTM0MzY2._V1_SX300.jpg"},
    {"title": "The Departed", "year": 2006, "rating": 8.5, "director": "Martin Scorsese",
     "description": "An undercover cop and a mole in the police attempt to identify each other while infiltrating an Irish gang in South Boston.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMTI1MTY2OTIxNV5BMl5BanBnXkFtZTYwNjQ4NjY3._V1_SX300.jpg"},
    {"title": "Whiplash", "year": 2014, "rating": 8.5, "director": "Damien Chazelle",
     "description": "A promising young drummer enrolls at a cut-throat music conservatory where his dreams of greatness are mentored by an instructor who stops at nothing.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BOTA5NDZlZGUtMjAxOS00YTRhLThmZGMtMjE2NzUzOGE0MTI3XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Parasite", "year": 2019, "rating": 8.5, "director": "Bong Joon Ho",
     "description": "Greed and class discrimination threaten the newly formed symbiotic relationship between the wealthy Park family and the destitute Kim clan.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BYjk1Y2U4MjQtY2ZiNS00OWQyLWI3MmYtZWUwNmRjYWRiNWNhXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Django Unchained", "year": 2012, "rating": 8.5, "director": "Quentin Tarantino",
     "description": "With the help of a German bounty-hunter, a freed slave sets out to rescue his wife from a brutal plantation owner.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMjIyNTQ5NjQ1OV5BMl5BanBnXkFtZTcwODg1MDU4OA@@._V1_SX300.jpg"},
    {"title": "The Lion King", "year": 1994, "rating": 8.5, "director": "Roger Allers",
     "description": "Lion prince Simba and his father are targeted by his bitter uncle, who wants to ascend the throne himself.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BYTYxNGMyZTYtMjE3MS00MzNjLWFjNmYtMDk1N2U3MmFmOWYxXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Avengers: Endgame", "year": 2019, "rating": 8.4, "director": "Anthony Russo",
     "description": "After the devastating events of Infinity War, the universe is in ruins. With the help of remaining allies, the Avengers assemble once more.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMTc5MDE2ODcwNV5BMl5BanBnXkFtZTgwMzI2NzQ2NzM@._V1_SX300.jpg"},
    {"title": "Joker", "year": 2019, "rating": 8.4, "director": "Todd Phillips",
     "description": "During the 1980s, a failed stand-up comedian is driven insane and turns to a life of crime and chaos in Gotham City.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BNGVjNWI4ZGUtNzE0MS00YTJmLWE0ZDctN2ZiYTk2YmI3NTYyXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Spirited Away", "year": 2001, "rating": 8.6, "director": "Hayao Miyazaki",
     "description": "During her family's move to the suburbs, a sullen 10-year-old girl wanders into a world ruled by gods, witches, and spirits.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BMjlmZmI5MDctNDE2YS00YWE0LWE5ZWItZDBhYWQ0NTcxNWRhXkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "The Silence of the Lambs", "year": 1991, "rating": 8.6, "director": "Jonathan Demme",
     "description": "A young F.B.I. cadet must receive the help of an incarcerated and manipulative cannibal killer to catch another serial killer.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BNDdhOGJhYzctNzZkOS00OWZmLTk0ODktM2ZiOGY5ZDRhNzM4XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Saving Private Ryan", "year": 1998, "rating": 8.6, "director": "Steven Spielberg",
     "description": "Following the Normandy Landings, a group of U.S. soldiers go behind enemy lines to retrieve a paratrooper whose brothers have been killed in action.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BZjhkMDM4MWItZTVjOC00ZDRhLThmYTAtM2I5NzBmNmNlMzI1XkEyXkFqcGc@._V1_SX300.jpg"},
    {"title": "Back to the Future", "year": 1985, "rating": 8.5, "director": "Robert Zemeckis",
     "description": "Marty McFly, a 17-year-old high school student, is accidentally sent thirty years into the past in a time-traveling DeLorean.",
     "image_url": "https://m.media-amazon.com/images/M/MV5BZmU0M2Y1OGUtZjIxNi00ZjBkLTg1MjgtOWIyNThiZWIwYjRiXkEyXkFqcGc@._V1_SX300.jpg"},
]

ACTOR_NAMES = [
    "Morgan Freeman", "Tim Robbins", "Marlon Brando", "Al Pacino", "Christian Bale",
    "Heath Ledger", "Leonardo DiCaprio", "Joseph Gordon-Levitt", "John Travolta", "Samuel L. Jackson",
    "Tom Hanks", "Robin Wright", "Keanu Reeves", "Laurence Fishburne", "Matthew McConaughey",
    "Anne Hathaway", "Brad Pitt", "Edward Norton", "Robert De Niro", "Ray Liotta",
    "Elijah Wood", "Viggo Mortensen", "Liam Neeson", "Ben Kingsley", "Russell Crowe",
    "Joaquin Phoenix", "Hugh Jackman", "Scarlett Johansson", "Jack Nicholson", "Matt Damon",
    "J.K. Simmons", "Miles Teller", "Song Kang-ho", "Choi Woo-shik", "Jamie Foxx",
    "Christoph Waltz", "James Earl Jones", "Robert Downey Jr.", "Chris Evans", "Jodie Foster",
    "Anthony Hopkins", "Rumi Hiiragi", "Miyu Irino", "Michael J. Fox", "Christopher Lloyd",
]

GENRE_NAMES = ['Action', 'Comedy', 'Drama', 'Fantasy', 'Horror', 'Mystery', 'Romance', 'Sci-Fi', 'Thriller', 'Animation', 'Crime', 'Adventure', 'War']


def seed_db():
    with app.app_context():
        db.drop_all()
        db.create_all()

        print("Seeding genres...")
        genres = {name: Genre(name=name) for name in GENRE_NAMES}
        db.session.add_all(genres.values())
        db.session.commit()

        print("Seeding actors...")
        actors = []
        for name in ACTOR_NAMES:
            actor = Actor(name=name, bio=f"{name} is an acclaimed actor known for numerous award-winning performances across film and television.")
            actors.append(actor)
        db.session.add_all(actors)
        db.session.commit()

        print("Seeding movies...")
        genre_map = {
            "The Shawshank Redemption": ["Drama"],
            "The Godfather": ["Crime", "Drama"],
            "The Dark Knight": ["Action", "Crime", "Drama"],
            "Inception": ["Action", "Sci-Fi", "Thriller"],
            "Pulp Fiction": ["Crime", "Drama"],
            "Forrest Gump": ["Drama", "Romance"],
            "The Matrix": ["Action", "Sci-Fi"],
            "Interstellar": ["Adventure", "Drama", "Sci-Fi"],
            "Fight Club": ["Drama", "Thriller"],
            "Goodfellas": ["Crime", "Drama"],
            "The Lord of the Rings: The Return of the King": ["Adventure", "Drama", "Fantasy"],
            "Schindler's List": ["Drama", "War"],
            "Gladiator": ["Action", "Adventure", "Drama"],
            "The Prestige": ["Drama", "Mystery", "Thriller"],
            "The Departed": ["Crime", "Drama", "Thriller"],
            "Whiplash": ["Drama", "Mystery"],
            "Parasite": ["Comedy", "Drama", "Thriller"],
            "Django Unchained": ["Drama", "Western"],
            "The Lion King": ["Animation", "Adventure", "Drama"],
            "Avengers: Endgame": ["Action", "Adventure", "Sci-Fi"],
            "Joker": ["Crime", "Drama", "Thriller"],
            "Spirited Away": ["Animation", "Adventure", "Fantasy"],
            "The Silence of the Lambs": ["Crime", "Drama", "Thriller"],
            "Saving Private Ryan": ["Drama", "War"],
            "Back to the Future": ["Adventure", "Comedy", "Sci-Fi"],
        }

        movies = []
        for m_data in REAL_MOVIES:
            movie = Movie(
                title=m_data["title"],
                release_year=m_data["year"],
                rating=m_data["rating"],
                director=m_data["director"],
                description=m_data["description"],
                image_url=m_data["image_url"],
            )
            movie_genres = genre_map.get(m_data["title"], ["Drama"])
            movie.genres = [genres[g] for g in movie_genres if g in genres]
            movie.actors = random.sample(actors, k=min(random.randint(5, 10), len(actors)))
            movies.append(movie)

        db.session.add_all(movies)
        db.session.commit()

        print("Generating 200 additional movies for stress testing...")
        extra_movies = []
        for i in range(200):
            base = random.choice(REAL_MOVIES)
            movie = Movie(
                title=f"{base['title']} (Volume {i+1})",
                release_year=base["year"],
                rating=base["rating"],
                director=base["director"],
                description=f"Synthetic expansion for Volume {i+1}: {base['description']}",
                image_url=base["image_url"],
            )
            movie.genres = [genres[g] for g in genre_map.get(base["title"], ["Drama"]) if g in genres]
            movie.actors = random.sample(actors, k=min(random.randint(3, 7), len(actors)))
            extra_movies.append(movie)
            
            if len(extra_movies) >= 50:
                db.session.add_all(extra_movies)
                db.session.commit()
                extra_movies = []
        
        if extra_movies:
            db.session.add_all(extra_movies)
            db.session.commit()

        # Add reviews
        all_movies = Movie.query.all()
        reviewers = ["Roger Ebert", "Peter Travers", "A.O. Scott", "Manohla Dargis", "David Ehrlich",
                      "Mark Kermode", "Pauline Kael", "Gene Siskel", "Leonard Maltin", "Richard Roeper"]
        reviews_list = []
        for movie in all_movies:
            for _ in range(random.randint(2, 4)):
                review = Review(
                    movie_id=movie.id,
                    author=random.choice(reviewers),
                    content=f"A masterful piece of cinema. {movie.title} showcases exceptional storytelling.",
                    score=random.randint(7, 10),
                )
                reviews_list.append(review)
        
        db.session.add_all(reviews_list)
        db.session.commit()

        print(f"Database seeded with {len(all_movies)} movies, {len(actors)} actors, and {len(reviews_list)} reviews.")


if __name__ == '__main__':
    seed_db()
