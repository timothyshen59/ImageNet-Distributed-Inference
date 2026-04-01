#app/metrics.py 

from prometheus_client import Histogram, Counter, Gauge 

# How long inference request is E2E
REQUEST_LATENCY = Histogram( 
    "inference_request_latency_seconds", 
    "End-to-end inference request_latency", 
    buckets = [0.01, 0.05, 0.1, 0.5, 1.0, 2.0]        
)

# How many requests have been processed total
REQUEST_COUNT = Counter( 
    "inference_request_total",
    "Total number of inference requests",
    ["status"]
)

# Batch size of batcher flushes 
BATCH_SIZE = Histogram(
    "inference_batch_size",
    "Number of requests per batch",
    buckets=[1, 2, 4, 8, 16, 32]               
)

# Size of Queue at any moment 
QUEUE_DEPTH = Gauge(
    "inference_queue_depth",
    "Current number of requests waiting in batcher queue"
)