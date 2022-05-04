# Proof of Concept: Snyk Security Scanners

This sample repository is used to explore and test the snyk scanner options.

We created this mono-repo to simulate a typical work package, with:
 - some [configuration](./config) files (eg: dev / prod K8S manifests)
 - a [simple REST api](./packages/api) (packaged as container)
 - we deploy the app as a [helm chart](./helm/sample) to Kubernetes.

## Types of security scans

The 3 levels of security scanners we run will be:

1) Package dependencies (eg: `npm modules` or `pip requirements.txt`)
2) Container base images (inferred from `./dist/artifacts.json`)
3) Helm charts and K8S deployment manifests (located in `./dist/k8s/`)

## Scan for issues locally

We have made it easy to test and scan locally, by making use of some scripts:

```
# Build sample docker image & helm chart locally
./snyk_build.sh

# Run the desired tests, and make sure they all pass
./snyk_test.sh

# Try and run the monitor commands
./snyk_monitor.sh
```

This will generate the required snyk commands and run them, for example:

```
snyk test --yarn-workspaces --severity-threshold=medium --fail-on=patchable

snyk test --severity-threshold=medium --fail-on=patchable --docker api:local
snyk test --severity-threshold=medium --fail-on=patchable --docker client:local

snyk iac test --severity-threshold=medium ./dist/manifests/sample.local.yaml
```

## Validating assumptions

One of the primary reasons for creating this sample repo was to test the
workflow of Snyk.io, and see if we can validate these steps with a simplified and fast pipeline. 

 - Create a new project if not exists
 - Continually track and monitor for new issues (daily, weekly)
 - Correctly track all resources (packages, images, charts), grouped per work package
 - Track the current target branch information so that we can support multiple environments

## Steps that was followed (in this sequence):
 - Create the sample work package, simulating the standard workflow
 - Add the new project directly to snyk.io, using the web dashboard.
 - Validate that the `snyk test` security scans run, but don't update Snyk.io
 - Modify scanner commmands to see if `snyk monitor` updates the project
 - Handle all edge cases, eg: create if not exists, scan docker images, scan helm charts

### Create the sample work package, simulating the standard workflow
 - This repo is the result of such an experiment, and represents a typical work package

### Add the new project directly to snyk.io, using the web dashboard.
 - The "project name" is in the format: `organisation/repo-name`
 - This will create a new project and does on-demand scans + set up daily scans
    - The daily scans are triggered correctly, but only tracks files that it could detect
    - This method does not correctly detect helm charts and has no idea of docker images
 - This method picks up a lot of YAML files used by Kustomize, potentially creating 'noise'

### Validate that the `snyk test` security scans run, but don't update Snyk.io
 - Correct, the scans run locally (or on CI/CD) only, and does not update Snyk dashboard
 - Worth noting, is that the scan gives detailed reports of what is scanned, lists issues
 - We can also potentially generate reports as output files, for each scan, for example
```
# Generate a JSON file containing scan results
snyk test --yarn-workspaces ...  --json-file-output=./dist/snyk/packages.json
snyk test --docker ...           --json-file-output=./dist/snyk/docker-api.json
snyk iac test  ...               --json-file-output=./dist/snyk/helm-charts.json

# Generate HTML report from the scan results
cat ./dist/snyk/packages.json | snyk-to-html -o report.html
```

### Modify scanner commmands to see if `snyk monitor` updates the project
 - Commands `snyk test` and `snyk monitor` seem to be interchangable, for the most part...
   - https://docs.snyk.io/snyk-cli/cli-reference
   - There are some CLI args not supported by both actions, the most important:
      - `--target-reference` is not supported by `snyk containers`
      - `--remote-repo-url` is not supported by `snyk containers` or `snyk iac`
 - First observation is that this creates a new project, and does not detect existing project
   - In fact, even changing "group name" to be identical, its still considered 2 groups (different ID's)
 - The "project name" is in the format: `/organisation/repo-name.git` (notice difference)
   - _With some efort and a lot of searching the internet, we found a way to name the group:_
   - `GROUP_NAME=$(git config --get remote.origin.url | sed -e 's/^.*://g' | sed -e 's/\.git$//g')`
   - `--remote-repo-url="$GROUP_NAME"` 
   - The `remote-repo-url` [workaround](https://support.snyk.io/hc/en-us/articles/360000910677-Snyk-CLI-monitored-projects-are-created-with-IDs-in-the-project-name) is not ideal, and needs a better documented solution IMHO
 - Advantage of `monitor` is that we only report on what we scan (less noise than web import)
    - This only applies to the `snyk open source` part (eg: _package dependencies_)    
 - Running `snyk monitor` on `docker images` is an issue, it does not detect the correct _group name_
    - Each image is tracked as a new project, creating an issue for tracking per work package
    - Not supported: `--remote-repo-url="$GROUP_NAME" `
 - Running `snyk monitor` on `infra-as-code` is also an issue, cannot set _group name_ or use `json` output:
    - When in monitor mode, it does not report (in the `stdout` of CI/CD) what issues to fix are...
    - Trying to explicitly set the project group or repo URL is not supported. :( 
    - `--target-reference="$BRANCH_NAME"`
    - `--remote-repo-url="$GROUP_NAME" `

 - Lets do the experiment and try to adapt the `snyk test` commands to `snyk monitor`,
given the knowledge we gained so far above...

```
# This one works quite well, sets correct group name, project names and target branch! :)
snyk monitor --yarn-workspaces --severity-threshold=medium --fail-on=patchable --policy-path=.snyk \
	--target-reference="$(git branch --show-current)" \
	--remote-repo-url="$(git config --get remote.origin.url | sed -e 's/^.*://g' | sed -e 's/\.git$//g')"

# Here we can scan the image, and set the project name + target branch, but it creates a new project :(
snyk container monitor api:115e9c74a8975b \
  --severity-threshold=medium \
  --fail-on=patchable \
	--project-name="docker/api" \
	--target-reference="$(git branch --show-current)" \
# The next line is not supported unfortunately...
#  --remote-repo-url="$(git config --get remote.origin.url | sed -e 's/^.*://g' | sed -e 's/\.git$//g')" 

# For helm charts (rendered k8s manifests), we can not set the group name or the target branch unfortunately :(
snyk iac test --severity-threshold=medium ./dist/manifests/sample.local.yaml \
# The target (eg: brach) tag is not supported for snyk iac unfortunately
#	--target-reference="$(git branch --show-current)" \
# The next line is not supported unfortunately...
#	--remote-repo-url="$(git config --get remote.origin.url | sed -e 's/^.*://g' | sed -e 's/\.git$//g')" 
```

  - > Conclusion: This implies that `snyk monitor` is _not suitable_ for our __docker images__ 
 or __helm templates__, as we cannot track them in a __pre-defined group__ of our choosing.

### Handle all edge cases, eg: create if not exists, scan docker images, scan helm charts
 - Using Snyk monitor, we can create a new project if not exists, but only for package deps
   - We can set group name with: `--remote-repo-url="$GROUP_NAME" `
 - Scanning docker images gets created as new project, not grouping by original project
   - Not Supported: `--remote-repo-url="$GROUP_NAME" `
 - We have no way of "inferring" generated K8S manifests, if we dont trigger scans from CI/CD
   - Not Supported: `--remote-repo-url="$GROUP_NAME"`
   - Not Supported: `--target-reference="$BRANCH_NAME"`







## Refferences
 - https://docs.snyk.io/snyk-cli/cli-reference
 - https://docs.snyk.io/snyk-cli/configure-the-snyk-cli
 - https://docs.snyk.io/snyk-cli/secure-your-projects-in-the-long-term/grouping-projects-by-branch-or-version
 - https://snyk.io/blog/getting-the-most-out-of-snyk-test/
 - https://snyk.io/blog/snyk-cli-cheat-sheet/
 - https://github.com/snyk/snyk-to-html
 - https://apidocs.snyk.io/?version=2022-04-06%7Eexperimental#overview
 - https://docs.snyk.io/integrations
 - https://docs.snyk.io/integrations/ci-cd-integrations
 - https://support.snyk.io/hc/en-us/articles/360000910677-Snyk-CLI-monitored-projects-are-created-with-IDs-in-the-project-name
 - https://snyk.docs.apiary.io/#reference/projects/all-projects/list-all-projects
