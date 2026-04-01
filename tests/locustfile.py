# locustfile.py
import os
import random
from locust import HttpUser, task, between
import logging

class InferenceUser(HttpUser):
    wait_time = between(0.1, 0.5)

    def on_start(self):
        image_dir = "test_images"
        files = [f for f in os.listdir(image_dir) if f.endswith((".jpg", ".png"))]
        logging.info(f"Found images: {files}")
        
        self.images = [
            (f, open(f"{image_dir}/{f}", "rb").read())
            for f in files
        ]
        logging.info(f"Loaded {len(self.images)} images")

    @task
    def single_image(self):
        logging.info("Firing request...")
        fname, data = random.choice(self.images)
        with self.client.post(
            "/inference",
            files=[("files", (fname, data, "image/jpeg"))],
            catch_response=True
        ) as response:
            logging.info(f"Response: {response.status_code} {response.text[:100]}")