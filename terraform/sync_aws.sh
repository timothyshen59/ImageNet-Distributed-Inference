#!/bin/bash
# Syncs AWS to current local image + models 
set -e

bash scripts/push_ecr.sh
bash scripts/upload_model.sh

echo "=== Setup complete ==="