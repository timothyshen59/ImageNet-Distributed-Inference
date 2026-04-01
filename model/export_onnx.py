# model/export_onnx.py

# model/export_onnx.py
import timm
import torch
from onnxruntime.quantization import quantize_dynamic, QuantType
import onnx
from onnxsim import simplify

model = timm.create_model("vit_base_patch16_224", pretrained=True)
model.eval()

dummy_input = torch.randn(1, 3, 224, 224)

# 1. Export with higher opset for better optimization coverage
torch.onnx.export(
    model,
    dummy_input,
    "model/vit.onnx",
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={
        "input":  {0: "batch_size"},
        "output": {0: "batch_size"},
    },
    opset_version=17,              # higher opset = more fused ops available
    do_constant_folding=True,
)
print("✅ vit.onnx exported")

# 2. Simplify the graph — removes redundant nodes
model_onnx = onnx.load("model/vit.onnx")
model_simplified, check = simplify(model_onnx)
assert check, "Simplified model failed validation"
onnx.save(model_simplified, "model/vit_simplified.onnx")
print("✅ vit_simplified.onnx")

# 3. Quantize to INT8 — biggest CPU speedup
quantize_dynamic(
    "model/vit_simplified.onnx",
    "model/vit_int8.onnx",
    weight_type=QuantType.QInt8
)
print("✅ vit_int8.onnx")