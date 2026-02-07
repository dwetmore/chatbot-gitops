# Chatbot GitOps

## Architecture

This repo uses Kustomize to manage Kubernetes manifests.

- `base/` defines the core chatbot deployment, service, ingress, and ConfigMap.
- `overlays/dev-ollama/` adds Ollama and OpenWebUI resources for a dev setup.

The chatbot container is configured via `base/configmap.yaml`. It sets `LLM_PROVIDER=ollama` and
points `OLLAMA_BASE_URL` at the in-cluster Ollama service (`http://ollama.chatbot.svc.cluster.local:11434`).
This lets the chatbot API call Ollama directly over the cluster network.

OpenWebUI is deployed in the dev overlay. Its deployment sets `OLLAMA_BASE_URL=http://ollama:11434`,
so OpenWebUI talks to the Ollama service through the Kubernetes DNS name and port exposed by
`overlays/dev-ollama/ollama.yaml`.

## Ingress URLs

- Chatbot ingress (base): `chat.example.invalid` (placeholder).
- Dev overlay nip.io hosts:
  - Chatbot: `chat.172.17.93.185.nip.io` (from `overlays/dev-ollama/patch-ingress-host.yaml`).
  - OpenWebUI: `webui.172.17.93.185.nip.io` (from `overlays/dev-ollama/openwebui-ing.yaml`).

Update the nip.io IP if your ingress controller IP changes.

## Useful commands

- `make render` to print the dev overlay manifests.
- `make validate` to ensure `kustomize build overlays/dev-ollama` succeeds.
- `make show-urls` to print the expected nip.io hostnames.
