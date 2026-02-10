# Chatbot GitOps: OpenWebUI + Ollama on MicroK8s

This repository defines a GitOps deployment for a chatbot stack on Kubernetes using Argo CD and Kustomize. It exists to provide a clean, reproducible way to run OpenWebUI + Ollama (plus the chatbot API) on a local MicroK8s-style environment.

## What you get

- GitOps-friendly Kubernetes manifests that Argo CD can continuously reconcile from Git.
- A `base/` layer for the chatbot API plus shared namespace/config resources.
- A `overlays/dev-ollama/` environment overlay that adds Ollama and OpenWebUI.
- Ingress-based access for both chatbot and OpenWebUI using nip.io hostnames in the dev overlay.
- Local-dev-friendly defaults (single-replica services, PVC-backed model/UI data, straightforward `make` commands).

## Architecture

Flow:

1. User calls OpenWebUI ingress.
2. OpenWebUI calls Ollama service (`http://ollama:11434`).
3. Chatbot API (separate service/ingress) also calls Ollama via in-cluster DNS.
4. Argo CD watches this repo and applies desired state into the cluster.

Core components:

- `chatbot` Deployment + Service + Ingress
- `ollama` Deployment + Service + PVC
- `openwebui` Deployment + Service + Ingress + PVC
- `chatbot-config` ConfigMap for model provider and endpoint settings

Namespace:

- Workloads are deployed to `chatbot`.

## Repo layout

- `base/`: reusable core resources (`Namespace`, `ConfigMap`, chatbot `Deployment`, `Service`, `Ingress`).
- `overlays/dev-ollama/`: environment-specific resources for Ollama/OpenWebUI and ingress host patching for dev.

## Deploy (GitOps)

Create an Argo CD `Application` that points to this repo and overlay:

- **Repo URL**: your fork/remote for this repository
- **Path**: `overlays/dev-ollama`
- **Destination namespace**: `chatbot`
- **Target revision**: `main` (or your branch)

Example `Application` manifest:

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

Apply it:

```bash
kubectl apply -f application.yaml
```

Sync:

```bash
argocd app sync chatbot-gitops
```

## Validate

```bash
kubectl get pods -n chatbot
kubectl get svc -n chatbot
kubectl get ingress -n chatbot
kubectl describe ingress chatbot -n chatbot
kubectl describe ingress openwebui -n chatbot
```

## Operations

Logs:

```bash
kubectl logs deploy/openwebui -n chatbot --tail=100 -f
kubectl logs deploy/ollama -n chatbot --tail=100 -f
```

Rollout restart:

```bash
kubectl rollout restart deploy/openwebui -n chatbot
kubectl rollout restart deploy/ollama -n chatbot
kubectl rollout restart deploy/chatbot -n chatbot
```

Update flow:

1. Commit and push manifest changes to Git.
2. Argo CD detects drift and syncs automatically (or sync manually).
3. Validate pods/services/ingress after reconciliation.

## Troubleshooting

- **OpenWebUI loads, but no models respond**  
  Check Ollama pod health and logs: `kubectl get pods -n chatbot` and `kubectl logs deploy/ollama -n chatbot`.

- **OpenWebUI cannot reach Ollama**  
  Confirm service DNS/port from deployment env (`OLLAMA_BASE_URL=http://ollama:11434`) and verify `kubectl get svc ollama -n chatbot`.

- **Chatbot cannot reach Ollama**  
  Verify `chatbot-config` has `OLLAMA_BASE_URL=http://ollama.chatbot.svc.cluster.local:11434` and restart chatbot deployment.

- **Ingress hostname does not resolve**  
  Ensure the nip.io host IP in ingress manifests matches your ingress controller IP, then re-apply/sync.

- **Argo CD shows OutOfSync after edits**  
  Confirm changes were pushed to the same branch used by `targetRevision`, then trigger a manual sync.

## Roadmap

- [ ] Add CI to run `kustomize build overlays/dev-ollama` on every PR.
- [ ] Review and tighten CPU/memory resource limits across workloads.
- [ ] Add security hardening notes (image pinning, network policies, secrets strategy).

## Related repos

- Application/source repository details (for example, `chatbot`, `notes-app`) are not linked in this repo yet.
