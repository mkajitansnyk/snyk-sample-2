export TARGET=${1:-dev}
export GROUP=$(git config --get remote.origin.url | sed -e 's/^.*://g' | sed -e 's/\.git$//g')

# Monitor yarn workspaces for package dependencies
snyk monitor \
    --yarn-workspaces \
    --severity-threshold=medium \
    --fail-on=patchable \
	--target-reference="$(git branch --show-current)" \
	--remote-repo-url=${GROUP}

# Monitor the container images
export IMAGE="api:local"
snyk container monitor ${IMAGE} \
    --severity-threshold=medium \
    --fail-on=patchable \
	--project-name="docker/api" \
	--target-reference="$(git branch --show-current)" \
	#--remote-repo-url=${GROUP}     # <-- Not supported... :/


# NOT SUPPORTED - Monitor IaC for the target environment 
#snyk monitor \
#    --file=./dist/manifests.${TARGET}.yaml \
#    --severity-threshold=medium \
#    --fail-on=patchable \
#	--package-manager=k8sconfig \
#	--target-reference="$(git branch --show-current)" \
#	--remote-repo-url=${GROUP}
