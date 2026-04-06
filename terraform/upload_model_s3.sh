#!/bin/bash
set -e

BUCKET=$(terraform output -raw bucket_name)

echo "[upload] Uploading models to s3://$BUCKET..."

# Upload Triton INT8 model
aws s3 cp ../triton_models/vit_int8/1/model.onnx \
  s3://$BUCKET/triton_models/vit_int8/1/model.onnx

# Upload legacy float32 model
aws s3 cp ../model/vit_legacy.onnx \
  s3://$BUCKET/model/vit_legacy.onnx

echo "[done] Models uploaded to s3://$BUCKET"