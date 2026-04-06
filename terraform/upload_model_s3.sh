#!/bin/bash
set -e

BUCKET=$(aws s3 ls | grep imagenet-distributedinference | awk '{print $3}')

echo "Uploading to s3://$BUCKET..."

# Triton INT8 model
aws s3 cp ../triton_models/vit_int8/1/model.onnx \
  s3://$BUCKET/triton_models/vit_int8/1/model.onnx

# Triton config  ← ADD THIS, initContainer downloads it too
aws s3 cp ../triton_models/vit_int8/config.pbtxt \
  s3://$BUCKET/triton_models/vit_int8/config.pbtxt

# Legacy float32 model
aws s3 cp ../model/vit_legacy.onnx \
  s3://$BUCKET/model/vit_legacy.onnx

echo "✅ Done"