export TARGET=${1:-dev}

# Snyk Open Source
snyk test \
    --yarn-workspaces \
    --severity-threshold=medium \
    --fail-on=patchable

# Snyk scan docker images (from a multistage build)
# This is one of many images to test, derived from ./dist/artifacts.json...
export IMAGE="api:local"
snyk container test ${IMAGE} \
    --severity-threshold=medium \
    --fail-on=patchable

# Snyk scan Infra-as-Code (iac) with generated template
snyk iac test \
    ./dist/manifests.$TARGET.yaml \
    --severity-threshold=medium \
    # --fail-on=patchable