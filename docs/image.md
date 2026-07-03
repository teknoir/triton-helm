# 📦 Triton Image

> _NVIDIA Triton Inference Server — the engine core._

The **Triton Image** is the container that powers every inference request.
It ships straight from NVIDIA's NGC registry, battle-tested for GPU serving.

## 🏷️ Coordinates

| Field | Value |
|-------|-------|
| Repository | `nvcr.io/nvidia/tritonserver` |
| Version | `25.02-py3` |

## ⚙️ Capabilities

- 🧠 Multi-framework: TensorRT, ONNX, PyTorch, TensorFlow & Python backends
- ⚡ Concurrent model execution on CPU **and** GPU
- 🔀 Dynamic batching for high throughput
- 🌐 Dual HTTP/REST + gRPC endpoints

## 🚏 Pulling

```bash
docker pull nvcr.io/nvidia/tritonserver:25.02-py3
```

!!! info "Sourced upstream"
    This image is maintained by NVIDIA; Teknoir consumes it unmodified via the
    [Triton HelmChart](helmchart.md).
