# Harness CI setup

The patch and upgrade logic is packaged as a reusable **Harness step group template**, [`templates/application-advisor.yaml`](templates/application-advisor.yaml). Developers add it to the CI stage of an existing pipeline. The demo's **Patch** and **Upgrade** pipelines, [`pipelines/patch.yaml`](pipelines/patch.yaml) and [`pipelines/upgrade.yaml`](pipelines/upgrade.yaml), are two consumers of that template. The GitHub connector, secrets, and project IDs are specific to your account, so create them after publishing this repository.

## The template

`account.application_advisor`, version `v4`, is a CI step group with two Run steps:

1. **Run Application Advisor**: writes Maven settings that mirror Broadcom's Spring Enterprise repository through a repository manager, downloads the advisor CLI through the same remote, runs `patch apply` or the next `upgrade-plan apply` step, then runs a verification command. It exports `CHANGED` and `OPERATION`.
2. **Open pull request**: runs only when `CHANGED` is `true`. It commits the changes to an `advisor-<operation>-<timestamp>` branch, pushes it, and opens a pull request against the branch the pipeline built, through the GitHub REST API. It exports `PR_URL`.

The template is self-contained: the target repository needs no scripts. It supports Maven projects on GitHub. The image needs a JDK 17+, `git`, and `curl`; `maven:3.9-eclipse-temurin-17` has all three, so the steps install nothing. Working files are never committed: the advisor's `.advisor/` and `target/`, and the `plugin-build-tool.json` that Harness's clone step writes.

| Input | Step | Value |
| --- | --- | --- |
| `connectorRef`, `image` | both | Container registry connector and image; see the AMD64 note below |
| `ADVISOR_OPERATION` | Run Application Advisor | `patch` or `upgrade` |
| `ADVISOR_VERSION` | Run Application Advisor | Advisor CLI version, default `1.7.1` |
| `MAVEN_MIRROR_URL` | Run Application Advisor | Repository manager remote for Spring Enterprise, e.g. `http://host.docker.internal:8082/artifactory/spring-enterprise-remote` |
| `MAVEN_MIRROR_USERNAME` | Run Application Advisor | Repository manager user, e.g. `admin` |
| `MAVEN_MIRROR_PASSWORD` | Run Application Advisor | Secret expression, e.g. `<+secrets.getValue("ARTIFACTORY_PASSWORD")>` |
| `VERIFY_COMMAND` | Run Application Advisor | Runs after the change, default `./mvnw -B test`; empty to skip |
| `GH_TOKEN` | Open pull request | Secret expression for a GitHub token that can push a branch and open a pull request |

Harness needs no Broadcom credentials. The Broadcom registry token lives only in the repository manager remote, which proxies Broadcom's Spring Enterprise repository for both Maven artifacts and the advisor CLI download. See [the Artifactory runbook](../artifactory/README.md).

To change the template, edit the YAML here and publish it as a new version label in Harness (**Templates → Application Advisor → New Version**). Pipelines stay on the version they reference until you move them.

### Add it to an existing pipeline

In a CI stage that clones a GitHub codebase and builds a branch, choose **Add Step → Use template → Application Advisor**, then fill in the inputs above. Add a weekly **cron trigger** for `patch`; run `upgrade` on demand.

## Demo setup

1. Create a GitHub connector for this repository (the demo uses `harness_advisor_demo`) and two project secrets, `ARTIFACTORY_PASSWORD` (the generated password in `demo/artifactory/.env`) and `GH_TOKEN`.
2. Create the template from [`templates/application-advisor.yaml`](templates/application-advisor.yaml) at account scope: **Account Settings → Templates → New Template → Import from YAML**, or paste it into the YAML view.
3. Create the **Patch** and **Upgrade** pipelines from the YAML in [`pipelines/`](pipelines/). Both build the `demo` branch.
4. Run **Patch**, review and merge its PR, then run **Upgrade**. Each Upgrade run applies one plan step; repeat it for another step if desired.

### AMD64 on an Apple Silicon local runner

Broadcom publishes the advisor CLI for Linux AMD64 only, so the step containers must run as AMD64. On a Mac local runner:

- The stage platform is **macOS / Arm64**. The local delegate is tagged `macos-arm64`, and Harness picks the delegate by platform selector; a Linux / AMD64 stage fails with "Delegate(s) don't have selectors [linux-amd64]".
- The Docker runner starts containers for the host architecture, ARM64. The demo pipelines therefore pin the image to the `linux/amd64` manifest digest of `maven:3.9-eclipse-temurin-17`, and Docker runs it under emulation. The template stops with a clear message if its container is not `x86_64`. Expect a patch run to take about 10–15 minutes under emulation.
- To refresh the pinned digest: `docker buildx imagetools inspect maven:3.9-eclipse-temurin-17` and copy the `linux/amd64` entry.

On AMD64 build infrastructure (Linux / AMD64 stages on Harness Cloud, Kubernetes, or VMs), use the image tag directly.

### Notes

The advisor CLI version is pinned because Artifactory OSS has no latest-version API and Broadcom publishes no `maven-metadata.xml` for the CLI. To check for a newer release, run this locally with your registry token, then raise `ADVISOR_VERSION`:

```bash
curl -fsS -H "Authorization: Bearer $BROADCOM_REGISTRY_TOKEN" \
  'https://packages.broadcom.com/artifactory/api/search/latestVersion?g=com.vmware.tanzu.spring&a=application-advisor-cli-linux&repos=spring-enterprise'
```

`advisor upgrade-plan get` and `advisor upgrade-plan apply` both exit with code 50 when some upgrades are blocked, even when the plan has steps and `apply` succeeds. The template treats 50 as success and relies on its changed-files check instead. Version history: v1 handled exit 50 only for `get`; v2 also handles it for `apply`; v3 keeps `.advisor/` and `target/` out of the commit through `.git/info/exclude`, because pathspec excludes make `git add` fail in repositories that already ignore those paths; v4 also excludes `plugin-build-tool.json`, a metrics file the Harness clone step writes to the workspace root.

Harness clones a fresh workspace for each execution. The Maven settings file and the advisor CLI live inside the disposable step container, outside the workspace; the CLI's commercial bytes are never checked into Git. [Harness CI pipeline setup](https://developer.harness.io/docs/continuous-integration/use-ci/prep-ci-pipeline-components/) explains the Build stage and Run step UI.

The local runner is the **runner process** on your machine, paired with a Harness delegate. A Run step executes in the **container image** chosen in that step; the Docker runner launches and manages those containers.

The scripts in `demo/scripts/` remain for local rehearsal (see the top-level README); the pipelines no longer call them.
