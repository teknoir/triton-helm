# ⚡ Triton Inference Server

> _Serve any model. On any device. At the speed of light._

Welcome to the **Teknoir Triton Inference Server** — a lean, GPU-accelerated
inference engine wrapped in a Kubernetes-native Helm chart and ready to deploy
across the Teknoir edge fleet.

```
      ╔══════════════════════════════════════════════╗
      ║   T R I T O N   ·   I N F E R E N C E   ·  ⚡  ║
      ╚══════════════════════════════════════════════╝
```

## 🧬 System Map

| Component | What it is | Docs |
|-----------|------------|------|
| 🚀 **Triton App** | The deployable inference application | [Open →](app.md) |
| ⎈ **Triton HelmChart** | Packaging & release artifact | [Open →](helmchart.md) |
| 📦 **Triton Image** | The NVIDIA Triton container | [Open →](image.md) |

## 🔭 At a Glance

- **Runtime:** NVIDIA Triton Inference Server `25.02-py3`
- **Chart version:** `0.2.1`
- **Registry:** `teknoir.github.io/triton-helm`
- **Owner:** `group:teknoir/public`
- **Lifecycle:** `production`

!!! tip "Fast lane"
    New here? Jump straight to the [Triton HelmChart](helmchart.md) to deploy
    in a single `helm install`.
