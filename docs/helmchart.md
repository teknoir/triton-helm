# ⎈ Triton HelmChart

> _One command. Full inference stack. Deployed._

The **Triton HelmChart** packages the Triton Inference Server for one-shot
delivery to any Kubernetes cluster in the Teknoir fleet.

## 📇 Coordinates

| Field | Value |
|-------|-------|
| Chart | `triton` |
| Version | `0.2.1` stable, `0.3.0-rc.1` pre-release (request with `version: 0.3.0-rc.1`) |
| App version | `25.02` |
| Registry | `teknoir.github.io/triton-helm` |

## 🛸 Deploy on Teknoir

```yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: triton
  namespace: default
spec:
  repo: https://teknoir.github.io/triton-helm
  chart: triton
  targetNamespace: default
  valuesContent: |-
    modelRepositoryPath: /opt/teknoir/models
    models: []
```

## 🧰 Manual Install

```bash
helm repo add teknoir-triton https://teknoir.github.io/triton-helm/
helm install triton teknoir-triton/triton -f values.yaml
```

## 🧠 Adding Models via Model Images

Models are delivered as **model images** — each becomes an init container that
copies its Triton model repository into the shared `/models` volume _before_
Triton boots. 🚀

```
   ┌────────────────────┐   copy /models   ┌──────────────┐
   │  model image (init) │ ───────────────▶ │ shared volume│──▶ Triton serves
   └────────────────────┘                   └──────────────┘
```

**1. Build a model image** — the [`rtdetr-triton`](https://github.com/teknoir/rtdetr-triton)
image bakes an ONNX RTDETR repo and `rsync`s it into the shared `/models` at
init time (the `CMD` runs when the init container starts):

```dockerfile
FROM alpine:3.22
RUN apk add --no-cache rsync
COPY ./universal/rtdetr/ /model/rtdetr/   # {config.pbtxt, labels.txt, 1/model.onnx}
CMD ["sh", "-c", "mkdir -p /models/rtdetr && rsync --checksum --delete -r /model/rtdetr/ /models/rtdetr/"]
```

**2. List each model** in `values.yaml` (one init container per entry):

```yaml
models:
- name: rtdetr
  image: ghcr.io/teknoir/rtdetr-triton:sha-0123abcd   # pin to an immutable sha-* tag
- name: up_down_classifier
  image: ghcr.io/teknoir/up-down-classifier-triton:latest
requiredModels: [rtdetr]   # pod is Ready only when rtdetr is ready
```

!!! warning "Git LFS"
    Build model images from a checkout with the real LFS files. Pointer files
    (~130 bytes) make Triton fail with `Protobuf parsing failed`.

**3. Deploy & verify**:

```bash
helm upgrade --install triton teknoir-triton/triton -f values.yaml
kubectl exec deploy/triton -- curl -s localhost:8000/v2/models/rtdetr/ready
```

!!! tip "Empty list?"
    With `models: []` no init containers run — Triton serves whatever already
    lives in `modelRepositoryPath` on the host.

## 🛡️ Robustness (0.3+)

- `tritonArgs.exitOnError: false` — a model that fails to load no longer stops Triton.
- `tritonArgs.strictReadiness: false` — one UNAVAILABLE model no longer makes the pod NotReady.
- `requiredModels: [...]` — readiness depends on exactly the models you need.
- `loadModels: [...]` — load only these model directories (explicit mode).
- `startupProbe` — slow model loading does not trip liveness.
- Model init container `imagePullPolicy`: auto (`IfNotPresent` for `sha-*`/digest refs, else `Always`).

A failed model shows as `UNAVAILABLE` in `POST /v2/repository/index` and as
`failed to load '<model>'` in the log.

## 🎛️ Key Values

```yaml
image:
  repository: nvcr.io/nvidia/tritonserver
  tag: 25.02-py3
tritonArgs:
  exitOnError: false
  strictReadiness: false
requiredModels: []
resources:
  limits:   { cpu: 2000m, memory: 4Gi }
  requests: { cpu: 400m,  memory: 256Mi }
nodePort:
  enabled: false
  httpPort: 31333
  grpcPort: 31334
```

See the chart README for the full table.

!!! warning "Small chart"
    This chart is intentionally small — just enough to get Triton flying.
