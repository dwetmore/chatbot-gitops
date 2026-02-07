KUSTOMIZE ?= kustomize

.PHONY: render validate show-urls

render:
	$(KUSTOMIZE) build overlays/dev-ollama

validate:
	$(KUSTOMIZE) build overlays/dev-ollama > /dev/null

show-urls:
	@echo "chat.172.17.93.185.nip.io"
	@echo "webui.172.17.93.185.nip.io"
