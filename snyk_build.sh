export TARGET=${1:-dev}

# Build the docker image locally
docker build --target=api-dist -t api:local .

# Get helm dependencies
helm dep build ./helm/sample

# Generate K8S manifests (for the target kubectl environment), with
# optional dependencies specified in ./config/$TARGET/values.yaml
helm template ./helm/sample \
    -n poc \
    -f ./config/${TARGET}/values.yaml \
    > ./dist/manifests.${TARGET}.yaml