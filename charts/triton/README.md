# Triton Inference Server Helm Chart

This chart deploys the Triton Inference Server to a Kubernetes cluster.

> Small chart: a Triton Deployment + Service, with model images copied in by init
> containers. Version 0.3 makes it robust against a single bad model (see
> [Robustness](#robustness-one-bad-model-must-not-take-everything-down)).

> **0.3.0 pre-releases** (`0.3.0-rc.N`) are not picked up by a `HelmChart` without
> `spec.version`, nor by `helm install` without `--devel`. Request them explicitly:
> `version: 0.3.0-rc.1`.

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
model image, which packages an ONNX RT-DETR object-detection model. Because an
init container must *actively copy* its files into the mounted volume, the image
is based on a small runtime with `rsync` rather than `FROM scratch` — the
container's `CMD` runs at init time and syncs the bundled repository into
`/models`:

```dockerfile
FROM alpine:3.22

RUN apk add --no-cache rsync

# The model repository is baked into the image at build time.
COPY ./universal/rtdetr/ /model/rtdetr/

# At init-container runtime, sync the model into the shared /models volume.
# --delete only prunes this model's own directory, never other models.
CMD ["sh", "-c", "mkdir -p /models/rtdetr && rsync --checksum --itemize-changes --delete -r /model/rtdetr/ /models/rtdetr/"]
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
> idempotent and only writes changed files. Without `--delete`, files from an
> older image of the same model stay in the volume, and Triton loads every
> directory it finds.

> **Git LFS:** if the model files are tracked in Git LFS, the build must check
> out the real files. A build from a checkout without `git lfs pull` bakes ~130
> byte *pointer files* into the image, and Triton fails with
> `Protobuf parsing failed`. Make the Dockerfile fail on pointer files and
> never ship a model image that was not inspected.

Build and push the image to a registry the cluster can pull from, and
reference it by an **immutable tag**:

```bash
docker build -t ghcr.io/teknoir/rtdetr-triton:sha-0123abcd .
docker push  ghcr.io/teknoir/rtdetr-triton:sha-0123abcd
```

### 2. Reference the model image in values

List each model in the `models` value, giving it a `name` and the `image` to
pull. One init container is created per model:

```yaml
models:
- name: rtdetr
  image: ghcr.io/teknoir/rtdetr-triton:sha-0123abcd
- name: up_down_classifier
  image: ghcr.io/teknoir/up-down-classifier-triton:latest
```

Init containers only run when a **new pod** starts (a values change, `kubectl
rollout restart deploy/triton`, a node reboot). A crash-looping Triton
container restarts *without* re-running them.

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
      image: ghcr.io/teknoir/rtdetr-triton:sha-0123abcd
    - name: up_down_classifier
      image: ghcr.io/teknoir/up-down-classifier-triton:latest
    # Models the NVR depends on: the pod is only Ready when they are
    requiredModels: [rtdetr]
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

## Robustness: one bad model must not take everything down

`tritonserver` defaults are all-or-nothing: with `--exit-on-error=true` a single
model that fails to load makes the whole server exit (every model is gone and the
pod crash-loops), and with `--strict-readiness=true` `/v2/health/ready` stays 503
while *any* model is unavailable, so the Service drops the pod. The chart
therefore defaults to:

| Value | Default | tritonserver flag |
|---|---|---|
| `tritonArgs.exitOnError` | `false` | `--exit-on-error` |
| `tritonArgs.strictReadiness` | `false` | `--strict-readiness` |
| `tritonArgs.logVerbose` | `0` | `--log-verbose` (was hardcoded `1`, which floods the log) |
| `tritonArgs.extraArgs` | `[]` | appended as-is |

A failed model is then **not fatal and not silent**: the log has
`failed to load '<model>'`, and `POST /v2/repository/index` lists it as
`UNAVAILABLE` with the reason. To make the pod's readiness depend on the models
you need, list them in `requiredModels`:

```yaml
requiredModels: [rtdetr]               # httpGet /v2/models/rtdetr/ready
# requiredModels: [rtdetr, pose]       # exec probe, curl each /v2/models/<m>/ready
```

- One name uses an `httpGet` probe. Two or more use an `exec` probe that needs
  `curl` in the Triton image (the `*-py3` images have it).
- Empty (default): readiness is `GET /v2/health/ready`.
- A name that does not exist in the repository keeps the pod NotReady forever.

`loadModels: [rtdetr, pose]` switches Triton to `--model-control-mode=explicit`
and loads only those directories, so stale directories from older model images
are ignored. Empty (default) loads every directory in the repository.

A `startupProbe` (`probes.startup`, default 5 min) covers the model loading
phase, so the liveness probe does not restart a Triton that is still loading
(Triton opens its ports only after the initial model load).

## Model image pull policy

Each model init container uses, in order: the model's own `imagePullPolicy`,
`modelImagePullPolicy` (default empty), then **auto**: `IfNotPresent` when the image
reference is immutable (`:sha-<hex>` or `@sha256:<digest>`), otherwise `Always`.
Auto keeps today's behaviour for mutable tags (`:latest`, branch tags) so a
moved tag is re-pulled, but stops pulling (and failing offline or behind a
registry outage) when the model image is pinned. Pin model images to
`sha-<sha8>` tags.

## Resources

Memory limit defaults to `4Gi` (was `2Gi`): one ONNX model alone uses 1.2-1.4 GiB
resident, and a robot typically loads several. Override with `resources.limits.memory`.

## Values

| Value | Default | Description |
|---|---|---|
| `image.repository`, `image.tag`, `image.pullPolicy` | `nvcr.io/nvidia/tritonserver`, `25.02-py3`, `Always` | Triton image |
| `modelRepositoryPath` | `/opt/teknoir/models` | hostPath mounted at `/models` |
| `models` | `[]` | `[{name, image, imagePullPolicy?}]`, one init container each |
| `modelImagePullPolicy` | `""` (auto) | see above |
| `tritonArgs.*` | see above | tritonserver flags |
| `loadModels` | `[]` | explicit model loading |
| `requiredModels` | `[]` | models that gate readiness |
| `probes.startup.{enabled,periodSeconds,failureThreshold}` | `true`, `5`, `60` | startup probe |
| `probes.readiness.{initialDelaySeconds,periodSeconds,timeoutSeconds}` | `5`, `5`, `5` | readiness probe timing |
| `resources` | 400m / 256Mi requests, 2000m / 4Gi limits | |
| `nodePort.{enabled,httpPort,grpcPort}` | `false`, `31333`, `31334` | |
| `nodeSelector` | `{}` | |
| `annotations` | `teknoir.org/managed-by: devstudio` | |

## Tests

```bash
helm lint charts/triton
helm lint charts/triton -f charts/triton/ci/robot-values.yaml
helm unittest charts/triton            # plugin: helm plugin install https://github.com/helm-unittest/helm-unittest
helm template t charts/triton -f charts/triton/ci/robot-values.yaml | kubeconform -strict -summary -
```

## Releasing

Pushes to `main` run `.github/workflows/release.yml` (chart-releaser: GitHub
release `triton-<version>` + `index.yaml` on `gh-pages`). Pushes to `beta` or
`beta/**` run `.github/workflows/beta.yml`, which refuses a version without a
pre-release suffix (`X.Y.Z-something`) and does not mark the release as latest.
chart-releaser never overwrites an existing release: bump the version
(`0.3.0-rc.2`) for every publish.

## Adding the repository

```bash
helm repo add teknoir-triton https://teknoir.github.io/triton-helm/
```

## Installing the chart

```bash
helm install triton teknoir-triton/triton -f values.yaml
```