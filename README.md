# Application Advisor + Harness CI demo

This repository is a repeatable customer demo using Spring PetClinic on **Spring Boot 3.5.14 / Java 17**. The story has two parts: apply security and bug-fix patches within the current release line, then run an Application Advisor upgrade plan to move to a newer line.

The baseline is 3.5.14, an open-source release from April 2026. Open-source support for 3.5 ended with 3.5.16, so the Patch run moves past the last open-source release to Broadcom's commercial 3.5.17. From 3.5.14 that fixes about 40 published advisories, including critical issues in Tomcat and Spring MVC. The Upgrade run then moves to Spring Boot 4.0. Harness CI runs them on a local Docker runner through a reusable step group template, and opens GitHub pull requests for review.

The application is based on the local Spring PetClinic `boot-3.4.2-baseline` at commit `15a06c1d05d78558f7c306cbc95f9190a9d9f97e`, with the Spring Boot parent raised to 3.5.14. PetClinic's original documentation is in [PETCLINIC.md](PETCLINIC.md), and its Apache 2.0 license is in [LICENSE.txt](LICENSE.txt).

## What's here

| Path | Purpose |
| --- | --- |
| `pom.xml`, `src/`, `mvnw` | Maven PetClinic application and Spring Enterprise repository declaration |
| `.advisor.yml` | Enables Application Advisor patch settings |
| `demo/scripts/` | Install CLI, configure disposable Maven credentials, run patch/upgrade, open PR, and reset |
| `demo/harness/` | Reusable Application Advisor step group template, the demo Patch/Upgrade pipelines, and the setup runbook |
| `demo/artifactory/README.md` | Optional free Artifactory OSS Maven remote cache |

## First run

1. Publish this repository to an empty GitHub repository. It has a `main` branch, a `demo` branch, and a `demo-baseline` tag:

   ```bash
   git remote add origin git@github.com:YOUR_ORG/harness-advisor-demo.git
   git push -u origin main
   git push -u origin demo
   git push origin demo-baseline
   ```

2. Have a Broadcom Spring Enterprise entitlement and registry token available. Enterprise artifacts and the advisor CLI download require it. Configure the token in the local Artifactory remote ([runbook](demo/artifactory/README.md)), then store `ARTIFACTORY_PASSWORD` and a GitHub `GH_TOKEN` as Harness secrets. Harness then needs no Broadcom credentials. Do not commit the values.
3. In Harness CI, connect this GitHub repository and follow [the Harness runbook](demo/harness/README.md). Use the local Docker runner as build infrastructure; on an Apple Silicon Mac the stage platform is macOS / Arm64 and the step image is pinned to AMD64, as the runbook explains. Harness Free supports the local runner; the delegate and runner process must be online when the pipeline starts.
4. Run the **Patch** pipeline against `demo`. Review its PR, merge it, and show the build result.
5. Run the **Upgrade** pipeline against `demo`. Review the plan and PR, then merge it. An upgrade run applies one plan step; repeat for another step if useful.

For a local rehearsal, install the advisor CLI, create your own `~/.m2/settings.xml` server with ID `spring-enterprise-subscription`, and run:

```bash
read -rsp 'Broadcom registry token: ' BROADCOM_REGISTRY_TOKEN; echo
export BROADCOM_REGISTRY_TOKEN
bash demo/scripts/install-advisor.sh
export PATH="$HOME/.local/bin:$PATH"
bash demo/scripts/run-advisor.sh plan
bash demo/scripts/run-advisor.sh patch
```

`demo/scripts/configure-maven.sh` can create Maven settings in a fresh home directory (such as a CI container), either from `ARTIFACTORY_URL` and `ARTIFACTORY_PASSWORD` or from `BROADCOM_EMAIL` and `BROADCOM_REGISTRY_TOKEN`. It refuses to overwrite existing settings. `install-advisor.sh` uses the same variables and installs a pinned CLI version (`ADVISOR_VERSION`, default `1.7.1`).

## Reset between takes

After merging the demo PRs, check out an up-to-date `demo` branch with a clean working tree and run:

```bash
git switch demo
git pull --ff-only origin demo
bash demo/scripts/reset-demo.sh
git push origin demo
```

The reset script restores all tracked files from `demo-baseline` and makes a new commit. It preserves the patch and upgrade PR history for the customer to inspect. Close any old unmerged demo PRs before the next run, then start new pipelines against `demo`. Keep `main` and the `demo-baseline` tag unchanged.

## Artifactory mirror

The Harness pipelines use [the Artifactory OSS runbook](demo/artifactory/README.md) setup: a Maven remote cache for Broadcom's Spring Enterprise repository. The repository remains upstream at Broadcom, while Artifactory caches requested artifacts, including the advisor CLI, locally. The mirror keeps the Broadcom token out of CI, and the Harness template requires one. The local rehearsal scripts can also go directly to Broadcom with `BROADCOM_EMAIL` and `BROADCOM_REGISTRY_TOKEN`.

## Limits

The template and pipeline YAML live in `demo/harness/`; the scripts are local rehearsal assets. The Harness connector, pipeline IDs, runner binding, and secrets are account-specific, so set those up in your Harness account after publishing. Application Advisor requires a valid Broadcom entitlement; without it, the app can still be built, but the patch and upgrade operations cannot run.
