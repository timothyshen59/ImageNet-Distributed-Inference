# tests/locustfile.py
import os
import random
from locust import HttpUser, task, between, tag
import logging

class InferenceUser(HttpUser):
    wait_time = between(0.1, 0.5)

    def on_start(self):
        image_dir = "tests/test_images"
        files = [f for f in os.listdir(image_dir) if f.endswith((".jpg", ".png"))]
        logging.info(f"Found images: {files}")
        
        self.images = [
            (f, open(f"{image_dir}/{f}", "rb").read())
            for f in files
        ]
        logging.info(f"Loaded {len(self.images)} images")

    @task
    @tag("triton")
    def infer_triton(self):
        fname, data = random.choice(self.images)
        with self.client.post(
            "/inference",
            files=[("files", (fname, data, "image/jpeg"))],
            catch_response=True
        ) as response:
            if response.status_code != 200:
                response.failure(f"Failed: {response.status_code}")

    @task
    @tag("legacy")
    def infer_legacy(self):
        fname, data = random.choice(self.images)
        with self.client.post(
            "/inference/v1",
            files=[("files", (fname, data, "image/jpeg"))],
            catch_response=True
        ) as response:
            if response.status_code != 200:
                response.failure(f"Failed: {response.status_code}")