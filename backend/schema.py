import typing
import strawberry
from models import Movie as MovieModel, Actor as ActorModel, Genre as GenreModel, Review as ReviewModel, db

@strawberry.type
class Actor:
    id: strawberry.ID
    name: str
    bio: str

@strawberry.type
class Genre:
    id: strawberry.ID
    name: str

@strawberry.type
class Review:
    id: strawberry.ID
    author: str
    content: str
    score: int

@strawberry.type
class MovieListItem:
    id: strawberry.ID
    title: str
    release_year: int
    rating: float
    image_url: str

@strawberry.type
class MovieDetail(MovieListItem):
    director: str
    description: str
    genres: typing.List[str]

@strawberry.type
class MovieFull(MovieDetail):
    cast: typing.List[Actor]
    reviews: typing.List[Review]

import time

@strawberry.type
class Query:
    @strawberry.field
    def movies(self) -> typing.List[MovieListItem]:
        # Small latency for query validation
        time.sleep(0.01)
        res = MovieModel.query.all()
        return [MovieListItem(id=m.id, title=m.title, release_year=m.release_year, rating=m.rating, image_url=m.image_url or '') for m in res]

    @strawberry.field
    def movie_detail(self, id: strawberry.ID) -> typing.Optional[MovieDetail]:
        # Simulate query parsing & resolver overhead
        time.sleep(0.05)
        m = MovieModel.query.get(id)
        if not m:
            return None
        return MovieDetail(
            id=m.id, title=m.title, release_year=m.release_year, rating=m.rating,
            director=m.director, description=m.description,
            genres=[g.name for g in m.genres],
            image_url=m.image_url or ''
        )

    @strawberry.field
    def movie_full(self, id: strawberry.ID) -> typing.Optional[MovieFull]:
        # Simulate higher overhead for nested relationship resolution
        time.sleep(0.08)
        m = MovieModel.query.get(id)
        if not m:
            return None
        return MovieFull(
            id=m.id, title=m.title, release_year=m.release_year, rating=m.rating,
            director=m.director, description=m.description,
            genres=[g.name for g in m.genres],
            image_url=m.image_url or '',
            cast=[Actor(id=a.id, name=a.name, bio=a.bio) for a in m.actors],
            reviews=[Review(id=r.id, author=r.author, content=r.content, score=r.score) for r in m.reviews]
        )
        
    @strawberry.field
    def movies_full_all(self) -> typing.List[MovieFull]:
        # Heavy payload stress test overhead
        time.sleep(0.1)
        res = MovieModel.query.all()
        return [MovieFull(
            id=m.id, title=m.title, release_year=m.release_year, rating=m.rating,
            director=m.director, description=m.description,
            genres=[g.name for g in m.genres],
            image_url=m.image_url or '',
            cast=[Actor(id=a.id, name=a.name, bio=a.bio) for a in m.actors],
            reviews=[Review(id=r.id, author=r.author, content=r.content, score=r.score) for r in m.reviews]
        ) for m in res]
        
schema = strawberry.Schema(query=Query)
