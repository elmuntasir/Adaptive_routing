# Movie API: REST vs GraphQL Energy Comparison

A research project comparing the energy consumption (carbon footprint) of REST and GraphQL APIs in mobile environments.

## 📁 Project Structure

- `backend/`: Flask server with REST and Strawberry GraphQL endpoints.
- `lib/`: Flutter mobile application (customizable for both API types).
- `benchmark/`: Python script for automated 1000-cycle fetch runs.
- `analysis/`: Pandas/Scipy analysis scripts for statistical significance.
- `gateway/`: Adaptive API Gateway prototype that routes requests based on green rankings.
- `paper/`: IEEE conference paper draft (LaTeX).

## 🚀 Getting Started

### 1. Backend Setup
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python seed.py  # Seeds ~500 movies and 2000 actors
python app.py   # Runs server at http://127.0.0.1:5005
```

### 2. Flutter App
Update `activeApiType` in `lib/main.dart` to toggle between REST and GraphQL for testing.
```bash
flutter pub get
flutter run
```

### 3. Benchmarking (Phase 3)
```bash
cd benchmark
python run_benchmark.py
```

### 4. Analysis & Gateway (Phase 4)
```bash
cd analysis
python analyze_benchmark.py  # Generates green_ranking.txt and plots
cd ../gateway
python gateway.py            # Starts adaptive proxy at http://127.0.0.1:5001
```

## 📊 Methodology Highlights
- **Device**: Android test device (RAPL on host laptop side).
- **Tooling**: PowerAPI for energy metrics (simulation enabled for local dev).
- **Statistical Metric**: Mann-Whitney U test (p < 0.05).
- **Payload Sizes**: 
  - Small (Title + Year + Rating)
  - Medium (Details + Director + Genres)
  - Large (Full Movie + Cast + Reviews)
