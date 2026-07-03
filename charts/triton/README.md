# Triton Inference Server Helm Chart

This chart deploys the Triton Inference Server to a Kubernetes cluster.

> The implementation of the Helm chart is right now the bare minimum to get it to work.

## Usage in Teknoir platform
Use the HelmChart to deploy the Triton Inference Server to a Device.

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
    # The path to the models directory
    modelRepositoryPath: /opt/teknoir/models
    # Models to be installed via a shared mounted host path (volume)
    models: []
```

## Adding models with model images

Models are added to the Triton Inference Server through **model images**. Each
entry in the `models` list is run as an [init container](charts/triton/templates/deployment.yaml)
that mounts the shared model volume at `/models` and copies its model artifacts
into it *before* the Triton server container starts. Triton then serves every
model found under `modelRepositoryPath` (mounted at `/models`).

### 1. Build a model image

A model image bundles a Triton-compatible
[model repository](https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/user_guide/model_repository.html)
and, when it runs as an init container, **copies that repository into the shared
`/models` volume**. The model directory must follow the Triton convention:

```
<model-name>
├── config.pbtxt      # model configuration
├── labels.txt        # (optional) class labels
└── 1                 # version directory
    └── model.<ext>   # e.g. model.onnx, model.plan, model.pt
```

A real-world example is the [`rtdetr-triton`](https://github.com/teknoir/rtdetr-triton)
model image, which packages an ONNX RTDETR object-detection model. Because an
init container must *actively copy* its files into the mounted volume, the image
is based on a small runtime with `rsync` rather than `FROM scratch` — the
container's `CMD` runs at init time and syncs the bundled repository into
`/models`:

```dockerfile
FROM alpine:3

RUN apk add --no-cache rsync

# The model repository is baked into the image at build time.
COPY ./universal/ /model/

# At init-container runtime, sync the repository into the shared /models volume.
CMD ["sh", "-c", "mkdir -p /models/ && rsync --checksum --itemize-changes -r /model/ /models/"]
```

Here `./universal/` contains the Triton model repository baked into the image:

```
universal/
└── rtdetr
    ├── config.pbtxt
    ├── labels.txt
    └── 1
        └── model.onnx
```

> Unlike a plain `COPY` into `/models`, the `rsync` **`CMD` executes when the
> init container starts**, copying the model into the shared volume that the
> Triton server container also mounts. Using `--checksum` makes repeated syncs
> idempotent and only writes changed files.

Build and push the image to a registry the cluster can pull from:

```bash
docker build -t ghcr.io/teknoir/rtdetr-triton:onnx-640x640-bs4 .
docker push  ghcr.io/teknoir/rtdetr-triton:onnx-640x640-bs4
```

### 2. Reference the model image in values

List each model in the `models` value, giving it a `name` and the `image` to
pull. One init container is created per model:

```yaml
models:
- name: rtdetr
  image: ghcr.io/teknoir/rtdetr-triton:onnx-640x640-bs4
- name: up_down_classifier
  image: us-docker.pkg.dev/teknoir/gcr.io/up-down-classifier-triton:latest
```

On the Teknoir platform, provide the same list via `valuesContent`:

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
    models:
    - name: rtdetr
      image: ghcr.io/teknoir/rtdetr-triton:onnx-640x640-bs4
    - name: up_down_classifier
      image: us-docker.pkg.dev/teknoir/gcr.io/up-down-classifier-triton:latest
```

### 3. Deploy and verify

```bash
helm upgrade --install triton teknoir-triton/triton -f values.yaml
```

Once the pod is running, confirm the models were loaded:

```bash
# List the init containers that populated the model volume
kubectl get pod -l app=triton -o jsonpath='{.items[0].spec.initContainers[*].name}'

# Ask Triton which models are ready
kubectl exec deploy/triton -- \
  curl -s localhost:8000/v2/models/rtdetr/ready
```

> **Note:** When `models` is empty (`models: []`), no init containers are added
> and Triton serves whatever already exists in `modelRepositoryPath` on the host.

## Adding the repository

```bash
helm repo add teknoir-triton https://teknoir.github.io/triton-helm/
```

## Installing the chart

```bash
helm install triton teknoir-triton/triton -f values.yaml
```