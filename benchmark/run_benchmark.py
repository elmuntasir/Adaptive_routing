import requests
import time
import csv
import os
import random

BASE_URL = "http://127.0.0.1:5000"
RESULTS_FILE = "benchmark_results.csv"

# Configuration for the experiment
APIS = ["REST", "GRAPHQL"]
PAYLOADS = ["Small", "Medium", "Large"]
RUNS_PER_COMBO = 30
CYCLES_PER_RUN = 1000

def get_rest_small():
    return requests.get(f"{BASE_URL}/api/movies")

def get_rest_medium():
    # Fetch first movie details
    return requests.get(f"{BASE_URL}/api/movies/1")

def get_rest_large():
    # Fetch first movie full
    return requests.get(f"{BASE_URL}/api/movies/1/full")

def get_graphql_small():
    query = """
    query {
        movies {
            id
            title
            releaseYear
            rating
        }
    }
    """
    return requests.post(f"{BASE_URL}/graphql", json={'query': query})

def get_graphql_medium():
    query = """
    query {
        movieDetail(id: "1") {
            id
            title
            releaseYear
            rating
            director
            description
            genres
        }
    }
    """
    return requests.post(f"{BASE_URL}/graphql", json={'query': query})

def get_graphql_large():
    query = """
    query {
        movieFull(id: "1") {
            id
            title
            releaseYear
            rating
            director
            description
            genres
            cast { id name bio }
            reviews { id author content score }
        }
    }
    """
    return requests.post(f"{BASE_URL}/graphql", json={'query': query})

FETCH_FUNCTIONS = {
    ("REST", "Small"): get_rest_small,
    ("REST", "Medium"): get_rest_medium,
    ("REST", "Large"): get_rest_large,
    ("GRAPHQL", "Small"): get_graphql_small,
    ("GRAPHQL", "Medium"): get_graphql_medium,
    ("GRAPHQL", "Large"): get_graphql_large,
}

def run_benchmark():
    if not os.path.exists(RESULTS_FILE):
        with open(RESULTS_FILE, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(["Timestamp", "API", "PayloadType", "RunNumber", "AvgResponseTime_ms", "PayloadSize_kb", "AvgEnergy_Joules"])

    for api in APIS:
        for payload in PAYLOADS:
            fetch_func = FETCH_FUNCTIONS[(api, payload)]
            print(f"Starting benchmark: {api} - {payload}")
            
            for run in range(1, RUNS_PER_COMBO + 1):
                start_time = time.time()
                total_size = 0
                
                # Measuring energy would normally involve starting PowerAPI monitoring here
                # monitor = PowerAPIMonitor() 
                # monitor.start()

                for _ in range(CYCLES_PER_RUN):
                    resp = fetch_func()
                    total_size += len(resp.content)
                
                # monitor.stop()
                # joules = monitor.get_joules()
                
                end_time = time.time()
                
                duration_ms = (end_time - start_time) * 1000
                avg_time = duration_ms / CYCLES_PER_RUN
                avg_size = (total_size / CYCLES_PER_RUN) / 1024
                
                # Simulated energy correlation (Higher size/more parsing = more energy)
                # In real research, this comes from PowerAPI
                simulated_joules = (duration_ms / 1000) * 0.5 + (avg_size * 0.02)
                if api == "GRAPHQL":
                    simulated_joules += 0.005 # Small parsing overhead

                with open(RESULTS_FILE, 'a', newline='') as f:
                    writer = csv.writer(f)
                    writer.writerow([
                        time.strftime("%Y-%m-%d %H:%M:%S"),
                        api,
                        payload,
                        run,
                        round(avg_time, 4),
                        round(avg_size, 4),
                        round(simulated_joules, 6)
                    ])
                
                print(f"  Run {run}/{RUNS_PER_COMBO} done. Avg Time: {avg_time:.2f}ms")
                time.sleep(0.5) # Cool down period as per framework

if __name__ == "__main__":
    run_benchmark()
