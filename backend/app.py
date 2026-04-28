import os
from flask import Flask, jsonify, request
from flask_cors import CORS
from models import db, Movie, Actor, Genre, Review
import strawberry
from strawberry.flask.views import GraphQLView
from schema import schema

app = Flask(__name__)
CORS(app) # Enable CORS for all routes
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(BASE_DIR, 'database.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)

import time
from flask import g

# Metrics storage
server_metrics_log = []

@app.before_request
def start_timer():
    g.start_cpu = time.process_time()
    g.start_real = time.perf_counter()

@app.after_request
def log_metrics(response):
    if not hasattr(g, 'start_cpu'):
        return response
        
    cpu_time = time.process_time() - g.start_cpu
    real_time = time.perf_counter() - g.start_real
    
    # Identify request type based on path
    path = request.path
    api_type = 'REST'
    if path == '/graphql':
        api_type = 'GRAPHQL'
    
    payload_type = 'Small'
    if '/all/full' in path: payload_type = 'Ultra'
    elif '/full' in path: payload_type = 'Large'
    elif any(x in path for x in ['/movies/', 'movieDetail']): payload_type = 'Medium'
    
    # Server Joule Model: CPU Time (more energy intensive) + Small baseline per request
    # Proxy: (CPU_seconds * 1.5) + (Static Overhead 0.001)
    s_joules = (cpu_time * 1.5) + 0.001
    
    server_metrics_log.append({
        'api_type': api_type,
        'task_type': payload_type,
        'cpu_ms': cpu_time * 1000,
        'joules': s_joules,
        'path': path
    })
    
    # Cap log size to 10,000 requests
    if len(server_metrics_log) > 10000:
        server_metrics_log.pop(0)
        
    return response

@app.route('/api/server-metrics', methods=['GET'])
def get_server_metrics():
    # Return last N metrics requested by client
    count = request.args.get('count', default=300, type=int)
    return jsonify(server_metrics_log[-count:])

@app.route('/api/server-metrics/clear', methods=['POST'])
def clear_server_metrics():
    server_metrics_log.clear()
    return jsonify({'status': 'cleared'})

# GraphQL setup
app.add_url_rule(
    "/graphql",
    view_func=GraphQLView.as_view("graphql_view", schema=schema),
)

# REST Endpoints
@app.route('/api/movies', methods=['GET'])
def get_movies():
    movies = Movie.query.all()
    # small payload
    return jsonify([
        {
            'id': m.id,
            'title': m.title,
            'release_year': m.release_year,
            'rating': m.rating,
            'image_url': m.image_url
        } for m in movies
    ])

@app.route('/api/movies/<int:movie_id>', methods=['GET'])
def get_movie_detail(movie_id):
    # medium payload
    m = Movie.query.get_or_404(movie_id)
    return jsonify({
        'id': m.id,
        'title': m.title,
        'release_year': m.release_year,
        'rating': m.rating,
        'director': m.director,
        'description': m.description,
        'genres': [g.name for g in m.genres],
        'image_url': m.image_url
    })

@app.route('/api/movies/<int:movie_id>/full', methods=['GET'])
def get_movie_full(movie_id):
    # large payload
    m = Movie.query.get_or_404(movie_id)
    return jsonify({
        'id': m.id,
        'title': m.title,
        'release_year': m.release_year,
        'rating': m.rating,
        'director': m.director,
        'description': m.description,
        'genres': [g.name for g in m.genres],
        'image_url': m.image_url,
        'cast': [
            {'id': a.id, 'name': a.name, 'bio': a.bio} for a in m.actors
        ],
        'reviews': [
            {'id': r.id, 'author': r.author, 'content': r.content, 'score': r.score} for r in m.reviews
        ]
    })
    
@app.route('/api/movies/all/full', methods=['GET'])
def get_all_movies_full():
    # ultra payload (stress test)
    movies = Movie.query.all()
    result = []
    for m in movies:
        result.append({
            'id': m.id,
            'title': m.title,
            'release_year': m.release_year,
            'rating': m.rating,
            'director': m.director,
            'description': m.description,
            'genres': [g.name for g in m.genres],
            'image_url': m.image_url,
            'cast': [{'id': a.id, 'name': a.name, 'bio': a.bio} for a in m.actors],
            'reviews': [{'id': r.id, 'author': r.author, 'content': r.content, 'score': r.score} for r in m.reviews]
        })
    return jsonify(result)

@app.route('/api/load', methods=['GET'])
def server_load():
    import threading
    active = threading.active_count()
    if active < 3:
        load = "low"
    elif active < 8:
        load = "medium"
    else:
        load = "high"
    return jsonify({"load": load})
    
@app.route('/api/movies/<int:movie_id>/cast', methods=['GET'])
def get_cast(movie_id):
    m = Movie.query.get_or_404(movie_id)
    return jsonify([{'id': a.id, 'name': a.name, 'bio': a.bio} for a in m.actors])

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5005)
