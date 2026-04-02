# model/export_onnx_legacy.py
import timm
import torch
import onnx
from onnxsim import simplify

model = timm.create_model("vit_base_patch16_224", pretrained=True)
model.eval()

dummy_input = torch.randn(1, 3, 224, 224)

# Export float32 — no quantization
torch.onnx.export(
    model,
    dummy_input,
    "model/vit_legacy.onnx",
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={
        "input":  {0: "batch_size"},
        "output": {0: "batch_size"},
    },
    opset_version=17,
    do_constant_folding=True,
)
print("✅ vit_legacy.onnx exported (float32)")