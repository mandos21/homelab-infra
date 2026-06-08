SHELL := /bin/bash

.PHONY: validate validate-flux validate-flux-apps validate-flux-infra validate-docs validate-renovate validate-structure

validate: validate-flux validate-docs validate-renovate validate-structure

validate-flux: validate-flux-apps validate-flux-infra

validate-flux-apps:
	@set -euo pipefail; \
	for file in $$(find k3s/cluster/flux/apps -name 'kustomization-*.yaml' -type f | sort); do \
		while read -r path; do \
			echo "==> kubectl kustomize $$path"; \
			kubectl kustomize "$$path" >/dev/null; \
		done < <(sed -n 's#^[[:space:]]*path: ./##p' "$$file"); \
	done

validate-flux-infra:
	@set -euo pipefail; \
	for file in $$(find k3s/cluster/flux/infrastructure k3s/cluster/flux/observability -name 'kustomization-*.yaml' -type f | sort); do \
		while read -r path; do \
			echo "==> kubectl kustomize $$path"; \
			kubectl kustomize "$$path" >/dev/null; \
		done < <(sed -n 's#^[[:space:]]*path: ./##p' "$$file"); \
	done

validate-docs:
	@set -euo pipefail; \
	if rg -n '/Users/mandos|/home/mandos/dev/homelab-infra' README.md docs k3s edge; then \
		echo "Absolute local paths found in docs"; \
		exit 1; \
	fi

validate-renovate:
	@python3 -c 'import json,re,sys; from pathlib import Path; data=json.loads(Path("renovate.json").read_text()); matches=[match for manager in data.get("customManagers", []) for pattern in manager.get("managerFilePatterns", []) for match in re.findall(r"k3s/[^\\\\\\\"]+?\\.ya\\?ml", pattern)]; missing=[candidate for candidate in (match.replace(r"\\.", ".").replace(r"\\?", "") for match in matches) if not Path(candidate).exists()]; [print("Renovate patterns refer to missing files:")] if missing else None; [print(path) for path in missing]; sys.exit(1 if missing else 0)'

validate-structure:
	@set -euo pipefail; \
	if find k3s/cluster/apps -type d -name core -empty | grep -q .; then \
		echo "Empty core directories found:"; \
		find k3s/cluster/apps -type d -name core -empty; \
		exit 1; \
	fi
