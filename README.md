# Chatbot GitOps: OpenWebUI + Ollama on MicroK8s

This repository contains Kubernetes manifests for deploying a local LLM stack with Argo CD and Kustomize on a MicroK8s-style cluster.

## Current deployed architecture

The actively deployed stack is:

- **Ollama**: in-cluster LLM runtime and HTTP API (`ollama:11434`)
- **OpenWebUI**: the only user-facing web interface

Runtime flow:

1. User accesses OpenWebUI through ingress.
2. OpenWebUI sends model requests directly to Ollama via in-cluster DNS (`http://ollama:11434`).
3. Argo CD reconciles the manifests from this repo.

## Repo layout

- `overlays/dev-ollama/`: deploys **only** Ollama and OpenWebUI (plus their PVCs, Service, and OpenWebUI Ingress).
- `base/`: older manifests present in the repo but not part of the `overlays/dev-ollama` deployment path.

## Ingress exposure (dev)

`overlays/dev-ollama/openwebui-ing.yaml` exposes only OpenWebUI using a nip.io hostname:

- `webui.172.17.93.185.nip.io`

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
