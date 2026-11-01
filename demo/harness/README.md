# Harness CI setup

The patch and upgrade logic is packaged as a reusable **Harness step group template**, [`templates/application-advisor.yaml`](templates/application-advisor.yaml). Developers add it to the CI stage of an existing pipeline. The demo's **Patch** and **Upgrade** pipelines, [`pipelines/patch.yaml`](pipelines/patch.yaml) and [`pipelines/upgrade.yaml`](pipelines/upgrade.yaml), are two consumers of that template. The GitHub connector, secrets, and project IDs are specific to your account, so create them after publishing this repository.

## The template

`account.application_advisor`, version `v6`, is a CI step group with two Run steps:

1. **Run Application Advisor**: writes Maven settings that mirror Broadcom's Spring Enterprise repository through a repository manager, downloads the advisor CLI through the same remote, runs `patch apply` or the next `upgrade-plan apply` step, then runs a verification command. It exports `CHANGED` and `OPERATION`.
2. **Open pull request**: runs only when `CHANGED` is `true`. It commits the changes to an `advisor-<operation>-<timestamp>` branch, pushes it, and opens a pull request against the branch the pipeline built, through the GitHub REST API. It exports `PR_URL`.

The pull request explains itself. An upgrade PR is titled after its Spring Boot step (for example, `upgrade spring-boot from 3.5.x to 4.0.x`) and its description holds the full upgrade plan the advisor computed before the change, including blocked upgrades. A patch PR lists every dependency change in a collapsible section. Both state the verification command that passed and link to the Harness execution. The first step writes the title and description under `.git/`, which the second step reads and which is never committed.

The template is self-contained: the target repository needs no scripts. It supports Maven projects on GitHub. The image needs a JDK 17+, `git`, and `curl`; `maven:3.9-eclipse-temurin-17` has all three, so the steps install nothing. Working files are never committed: the advisor's `.advisor/` and `target/`, and the `plugin-build-tool.json` that Harness's clone step writes.

| Input | Step | Value |
| --- | --- | --- |
| `connectorRef`, `image` | both | Container registry connector and an AMD64 image; see the build infrastructure notes below |
| `ADVISOR_OPERATION` | Run Application Advisor | `patch` or `upgrade` |
| `ADVISOR_VERSION` | Run Application Advisor | Advisor CLI version, default `1.7.1` |
| `MAVEN_MIRROR_URL` | Run Application Advisor | Repository manager remote for Spring Enterprise, reachable from the step container, e.g. `http://192.168.5.40:8082/artifactory/spring-enterprise-remote` |
| `MAVEN_MIRROR_USERNAME` | Run Application Advisor | Repository manager user, e.g. `admin` |
| `MAVEN_MIRROR_PASSWORD` | Run Application Advisor | Secret expression, e.g. `<+secrets.getValue("ARTIFACTORY_PASSWORD")>` |
| `VERIFY_COMMAND` | Run Application Advisor | Runs after the change, default `./mvnw -B test`; empty to skip. The demo pipelines exclude the Docker-based database tests (see below) |
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

### Build infrastructure: a Linux AMD64 host

The demo runs Harness CI and Artifactory on one Linux AMD64 machine on the local network (`192.168.5.40`, Ubuntu). Broadcom publishes the advisor CLI for Linux AMD64 only, so the step containers run natively there; a patch run takes about 7 minutes. On that host:

- **Artifactory** runs from `demo/artifactory/` with `ARTIFACTORY_BIND_ADDRESS=0.0.0.0` in its `.env`, so step containers and the presenter's laptop can reach `http://192.168.5.40:8082`. See [the Artifactory runbook](../artifactory/README.md).
- **Harness Docker runner** v0.1.30 (`harness-docker-runner-linux-amd64`) runs as the systemd service `harness-docker-runner`, bound to loopback with `HTTPS_BIND=127.0.0.1:3000`.
- **Harness delegate** `advisor-demo-linux` runs in Docker with host networking, the account-level delegate token `advisor-demo-linux`, `DELEGATE_TAGS=linux-amd64`, and `RUNNER_URL=http://127.0.0.1:3000`. The stage platform **Linux / AMD64** selects it through the `linux-amd64` tag.

```bash
sudo systemctl status harness-docker-runner
docker ps --filter name=advisor-demo-delegate --filter name=advisor-artifactory
```

To install the delegate, copy the Docker command from **Project Settings → Delegates → New Delegate → Docker** and change it as above. Keep the token out of Git and shell history: put `DELEGATE_TOKEN=...` in a mode-600 `--env-file`, then delete the file once the container starts.

The step containers use the plain `maven:3.9-eclipse-temurin-17` tag and reach Artifactory through the host's LAN address; `host.docker.internal` does not exist on Linux Docker by default.

The Linux runner mounts the host's Docker socket into step containers, so Testcontainers can start containers there. PetClinic's MySQL and Postgres integration tests would then run instead of skipping: the Postgres test needs a `docker-compose.yml` that this repository does not include, and the MySQL test fails to initialise MySQL 9.3 on this host after a six-minute wait. The demo pipelines therefore set `VERIFY_COMMAND` to `./mvnw -B test -Dtest='!MySqlIntegrationTests,!PostgresIntegrationTests' -Dsurefire.failIfNoSpecifiedTests=false`. The other 54 tests run, including the JPA tests on H2.

### Alternative: an Apple Silicon local runner

The pipelines can also run on a Mac. Tag the delegate `macos-arm64`, set the stage platform to **macOS / Arm64**, and pin the step image to the `linux/amd64` manifest digest of `maven:3.9-eclipse-temurin-17` (find it with `docker buildx imagetools inspect maven:3.9-eclipse-temurin-17`), so Docker runs it under Rosetta emulation. A Linux / AMD64 stage fails there with "Delegate(s) don't have selectors [linux-amd64]". The template stops with a clear message if its container is not `x86_64`. Expect a patch run to take about 11 minutes.

### Notes

The advisor CLI version is pinned because Artifactory OSS has no latest-version API and Broadcom publishes no `maven-metadata.xml` for the CLI. To check for a newer release, run this locally with your registry token, then raise `ADVISOR_VERSION`:

```bash
curl -fsS -H "Authorization: Bearer $BROADCOM_REGISTRY_TOKEN" \
  'https://packages.broadcom.com/artifactory/api/search/latestVersion?g=com.vmware.tanzu.spring&a=application-advisor-cli-linux&repos=spring-enterprise'
```

`advisor upgrade-plan get` and `advisor upgrade-plan apply` both exit with code 50 when some upgrades are blocked, even when the plan has steps and `apply` succeeds. The template treats 50 as success and relies on its changed-files check instead. Version history: v1 handled exit 50 only for `get`; v2 also handles it for `apply`; v3 keeps `.advisor/` and `target/` out of the commit through `.git/info/exclude`, because pathspec excludes make `git add` fail in repositories that already ignore those paths; v4 also excludes `plugin-build-tool.json`, a metrics file the Harness clone step writes to the workspace root. v5 writes a descriptive PR title and description: the upgrade plan for upgrade runs, the dependency changes for patch runs, the verification result, and a link to the Harness execution. v6 runs on Linux hosts, where the step container (root) does not own the runner's workspace: it marks the workspace as a git `safe.directory`, and a failing `git status` now stops the step instead of reading as "no changes". It also extracts the patch's `group:artifact:version → version` changes directly, because under Harness the advisor's progress frames could land in the PR's dependency list and count. Versions v1–v4 were deleted from Harness once superseded.

Harness clones a fresh workspace for each execution. The Maven settings file and the advisor CLI live inside the disposable step container, outside the workspace; the CLI's commercial bytes are never checked into Git. [Harness CI pipeline setup](https://developer.harness.io/docs/continuous-integration/use-ci/prep-ci-pipeline-components/) explains the Build stage and Run step UI.

The local runner is the **runner process** on the build host, paired with a Harness delegate. A Run step executes in the **container image** chosen in that step; the Docker runner launches and manages those containers.

The scripts in `demo/scripts/` remain for local rehearsal (see the top-level README); the pipelines no longer call them.
