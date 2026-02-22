# Chatbot GitOps: OpenWebUI + Ollama on MicroK8s

GitOps deployment repo for the in-cluster chatbot stack managed by Argo CD.

## What this repo controls

- Kubernetes manifests for Ollama and Open WebUI.
- `chatbot` namespace runtime for local LLM chat.
- Argo CD reconciliation from `main`.

## Current architecture (as of 2026-02-22)

Runtime components in `chatbot` namespace:

- `Deployment/ollama`
- `Deployment/openwebui`
- `Service/ollama` (`11434/TCP`)
- `Service/openwebui` (`80/TCP`)
- `Ingress/openwebui` host: `webui.172.17.93.185.nip.io`

Active traffic path:

1. Browser -> `webui.172.17.93.185.nip.io`
2. Open WebUI -> `http://finops-api.llm-finops.svc.cluster.local/proxy`
3. FinOps proxy -> `http://ollama.chatbot.svc.cluster.local:11434`

This path is required for FinOps token/cost attribution.

## Important cleanup state

- Duplicate Open WebUI stack in `default` namespace was removed.
- Host collision on `webui.172.17.93.185.nip.io` resolved.
- One-shot `ollama-model-pull` Job was removed from desired state (`kustomization.yaml`) to avoid persistent completed zombie jobs.

## Repo layout

- `overlays/dev-ollama/`: active overlay used by Argo.
- `base/`: legacy/deprecated; not used by active app path.

## Deploy with Argo CD

Use:

- Repo: `https://github.com/dwetmore/chatbot-gitops.git`
- Path: `overlays/dev-ollama`
- Namespace: `chatbot`
- Revision: `main`

Example `Application`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: chatbot
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
    syncOptions:
      - CreateNamespace=true
```

## Validate deployment

```bash
microk8s kubectl get deploy,svc,ingress -n chatbot
microk8s kubectl get pods -n chatbot
microk8s kubectl -n chatbot get deploy openwebui -o yaml | rg 'OLLAMA_BASE_URL|value:'
```

Expected `OLLAMA_BASE_URL`:

- `http://finops-api.llm-finops.svc.cluster.local/proxy`

## Operations

```bash
microk8s kubectl logs deploy/openwebui -n chatbot --tail=200 -f
microk8s kubectl logs deploy/ollama -n chatbot --tail=200 -f
microk8s kubectl rollout restart deploy/openwebui -n chatbot
microk8s kubectl rollout restart deploy/ollama -n chatbot
```

## Optional one-off model pre-pull

`overlays/dev-ollama/ollama-model-pull-job.yaml` is intentionally not in `kustomization.yaml`.
Use it only as an ad-hoc action.

Run manually when needed:

```bash
microk8s kubectl -n chatbot apply -f overlays/dev-ollama/ollama-model-pull-job.yaml
microk8s kubectl -n chatbot logs job/ollama-model-pull -f
microk8s kubectl -n chatbot delete job ollama-model-pull
```

Edit model list in:

- `overlays/dev-ollama/models.txt`

## Troubleshooting

If Open WebUI responds but FinOps dashboard shows no new cost:

1. Confirm Open WebUI is routing to FinOps proxy (env var above).
2. Confirm FinOps upstream points to chatbot Ollama service.
3. Confirm pricing rules exist for emitted model/provider.
4. Run FinOps metering for the period you are viewing.

If Argo keeps reverting a manual change, commit to Git and sync; do not patch live-only.
