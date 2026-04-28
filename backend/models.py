from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

# Cast join table
cast_table = db.Table('cast',
    db.Column('movie_id', db.Integer, db.ForeignKey('movie.id'), primary_key=True),
    db.Column('actor_id', db.Integer, db.ForeignKey('actor.id'), primary_key=True)
)

movie_genre_table = db.Table('movie_genre',
    db.Column('movie_id', db.Integer, db.ForeignKey('movie.id'), primary_key=True),
    db.Column('genre_id', db.Integer, db.ForeignKey('genre.id'), primary_key=True)
)

class Movie(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    release_year = db.Column(db.Integer)
    rating = db.Column(db.Float)
    director = db.Column(db.String(100))
    description = db.Column(db.Text)
    image_url = db.Column(db.String(500))
    
    genres = db.relationship('Genre', secondary=movie_genre_table, backref=db.backref('movies', lazy='dynamic'))
    actors = db.relationship('Actor', secondary=cast_table, backref=db.backref('movies', lazy='dynamic'))
    reviews = db.relationship('Review', backref='movie', lazy=True)

class Actor(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    bio = db.Column(db.Text)

class Genre(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), nullable=False)

class Review(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    movie_id = db.Column(db.Integer, db.ForeignKey('movie.id'), nullable=False)
    author = db.Column(db.String(100))
    content = db.Column(db.Text)
    score = db.Column(db.Integer)
