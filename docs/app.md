# 🚀 Triton App

> _The Teknoir Triton Inference Server — deployed._

The **Triton App** is the running inference application on a Teknoir device.
It fuses the [Triton Image](image.md) with the [Triton HelmChart](helmchart.md)
into a single, production-ready workload.

## 🧩 Composition

```
   ┌──────────────┐      ┌────────────────────┐
   │  Triton App  │──────│   Triton HelmChart  │
   └──────┬───────┘      └────────────────────┘
          │
          ▼
   ┌────────────────────────────┐
   │  nvcr.io/nvidia/tritonserver│  📦
   └────────────────────────────┘
```

## 🔌 Endpoints

| Protocol | Default NodePort |
|----------|------------------|
| HTTP     | `31333` |
| gRPC     | `31334` |

!!! note
    NodePorts are exposed only when `nodePort.enabled: true`.

## 🧠 Models

Models are mounted from a shared host path and discovered at runtime:

```yaml
modelRepositoryPath: /opt/teknoir/models
models: []
```

## 🛰️ Lifecycle

- **Type:** `app`
- **Owner:** `group:teknoir/public`
- **Lifecycle:** `production`
