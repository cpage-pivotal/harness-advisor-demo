# Harness CI setup

The app and scripts are stored here; create the Harness pipeline after publishing this repository because the GitHub connector and Harness project IDs are specific to your account.

1. In Harness CI, create a GitHub connector with read access to this repository. Set the pipeline codebase to the `demo` branch.
2. Add a **Build** stage on the **Local Runner (Docker)** infrastructure. Select the delegate/runner you already started, Linux / AMD64, and a Java 17 image such as `maven:3.9-eclipse-temurin-17`. Docker on an Apple Silicon host may run that image through AMD64 emulation.
3. Add three Harness secrets and expose them to the Run step as environment variables: `BROADCOM_EMAIL`, `BROADCOM_REGISTRY_TOKEN`, and `GH_TOKEN`. The GitHub token needs permission to push a branch and create a pull request. For a dry run, omit `GH_TOKEN` and skip the publish command.
4. Make a pipeline named **Patch** with one Run step using the commands below. Make a second pipeline named **Upgrade** and change `patch` to `upgrade` in the last two lines. Run both against `demo`, merging the patch PR before running Upgrade. The suggested Maven image is Debian based; its package manager installs the GitHub CLI for PR creation.

```bash
set -euo pipefail
apt-get update -qq
apt-get install -y -qq gh git curl
git fetch origin demo
git switch -C demo FETCH_HEAD
bash demo/scripts/configure-maven.sh
bash demo/scripts/install-advisor.sh
export PATH="$HOME/.local/bin:$PATH"
bash demo/scripts/run-advisor.sh patch
bash demo/scripts/publish-pr.sh patch
```

The `upgrade` command applies one planned step per run. Repeat it for another step if desired. To show the plan without making changes, use `bash demo/scripts/run-advisor.sh plan`.

Harness clones a fresh workspace for each execution. The Maven settings file is created inside the disposable Run step container. The Application Advisor CLI is downloaded there; its commercial bytes are not checked into Git. [Harness CI pipeline setup](https://developer.harness.io/docs/continuous-integration/use-ci/prep-ci-pipeline-components/) explains the Build stage and Run step UI.

The local runner is the **runner process** on your machine, paired with a Harness delegate. A pipeline Run step executes in a **container image** chosen in that step. The container image is the execution environment, rather than the runner itself. The Docker runner launches and manages those step containers.

The `git fetch` and `git switch` commands handle Harness checking out a detached commit. Run the pipeline manually against the `demo` branch, not a pull request ref.
