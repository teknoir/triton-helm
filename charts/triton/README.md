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

## Example values.yaml

```yaml
models:
- name: rtdetr
  image:  us-docker.pkg.dev/teknoir/gcr.io/rtdetr-triton:latest
- name: up_down_classifier
  image:  us-docker.pkg.dev/teknoir/gcr.io/up-down-classifier-triton:latest
```

## Adding the repository

```bash
helm repo add teknoir-triton https://teknoir.github.io/triton-helm/
```

## Installing the chart

```bash
helm install triton teknoir-triton/triton -f values.yaml
```