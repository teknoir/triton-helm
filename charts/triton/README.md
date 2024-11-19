# Triton Inference Server Helm Chart

This chart deploys the Triton Inference Server to a Kubernetes cluster.

> The implementation of the Helm chart is right now the bare minimum to get it to work.

## Example values.yaml

```yaml
# Values needed for Triton Inference Server
triton:
  # The path to the models directory
  modelRepositoryPath: /opt/teknoir/models
  # Models to be installed via a shared mounted host path (volume)
  models:
    - name: rtdetr
      image:  us-docker.pkg.dev/teknoir/gcr.io/rtdetr-triton:latest
    - name: up_down_classifier
      image:  us-docker.pkg.dev/teknoir/gcr.io/up-down-classifier-triton:latest
```