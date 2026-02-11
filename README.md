# Chatbot GitOps: OpenWebUI + Ollama on MicroK8s

This repository contains Kubernetes manifests for deploying a local LLM stack with Argo CD and Kustomize on a MicroK8s-style cluster.

## Current deployed architecture

The active deployment includes only:

- **Ollama**: in-cluster LLM runtime + HTTP API at `http://ollama:11434`
- **OpenWebUI**: the only user-facing web UI; it calls Ollama via in-cluster DNS

Runtime flow:

1. User opens OpenWebUI through ingress.
2. OpenWebUI sends model requests to `http://ollama:11434`.
3. Argo CD reconciles manifests from this repo.

## Repo layout

- `overlays/dev-ollama/`: deploys only Ollama + OpenWebUI (PVCs, Services, and OpenWebUI Ingress).
- `base/`: deprecated legacy manifests; not used by `overlays/dev-ollama`.

## Ingress exposure (dev)

Ingress exposes **only OpenWebUI** (no chatbot ingress).

Use this hostname pattern:

- `webui.<WSLIP>.nip.io`

Get `WSLIP` in WSL:

```bash
hostname -I | awk '{print $1}'
```

## Deploy with Argo CD

Create an Argo CD `Application` pointing at the dev overlay:

- **Repo URL**: your fork/remote for this repository
- **Path**: `overlays/dev-ollama`
- **Destination namespace**: `chatbot`
- **Target revision**: `main` (or your branch)

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: chatbot-gitops
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/dwetmore/chatbot-gitops.git
    targetRevision: main
    path: overlays/dev-ollama
  destination:
    server: https://kubernetes.default.svc
    namespace: chatbot
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Apply and sync:

```bash
kubectl apply -f application.yaml
argocd app sync chatbot-gitops
```


## Pre-pull Ollama models with a Job

The dev overlay includes:

- `ConfigMap/ollama-models` with a `models.txt` list of models to pull.
- `Job/ollama-model-pull` that reads `models.txt` and runs `ollama pull` for each entry.

Update the model list by editing `overlays/dev-ollama/ollama-models-configmap.yaml` and changing `data.models.txt`.

Trigger the model-pull Job:

```bash
kubectl delete job ollama-model-pull -n chatbot --ignore-not-found
kubectl apply -k overlays/dev-ollama
kubectl logs job/ollama-model-pull -n chatbot -f
```

Check completion:

```bash
kubectl get job ollama-model-pull -n chatbot
```

## Validate

```bash
kubectl get pods -n chatbot
kubectl get svc -n chatbot
kubectl get ingress -n chatbot
kubectl describe ingress openwebui -n chatbot
```

## Operations

```bash
kubectl logs deploy/openwebui -n chatbot --tail=100 -f
kubectl logs deploy/ollama -n chatbot --tail=100 -f
kubectl rollout restart deploy/openwebui -n chatbot
kubectl rollout restart deploy/ollama -n chatbot
```
