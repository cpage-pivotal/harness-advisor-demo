# Artifactory OSS Maven cache

This demo runs Artifactory OSS and PostgreSQL in Docker on the CI host (a Linux AMD64 machine at `192.168.5.40`; see [the Harness runbook](../harness/README.md)), then creates a Maven remote repository named `spring-enterprise-remote`. It points to Broadcom's Spring Enterprise repository and caches artifacts as they are requested. This is an on-demand cache, not a complete copy of the upstream repository.

## Start and configure

On the Artifactory host, copy `compose.yaml` and `start-local.sh` from this directory and start it:

```bash
bash start-local.sh
```

The first start creates a private `.env` with generated passwords. Artifactory listens on loopback unless `.env` sets `ARTIFACTORY_BIND_ADDRESS=0.0.0.0`; the demo host sets it so that CI containers and the presenter's laptop can reach port 8082. To reuse the existing `ARTIFACTORY_PASSWORD` Harness secret on a new host, copy the existing `.env` there (mode 600) before the first start.

Then configure the remote from a machine that has `vars.yaml`, Ruby, and this directory's `.env`. `ARTIFACTORY_URL` points the scripts at the host (default `http://localhost:8082`):

```bash
export ARTIFACTORY_URL=http://192.168.5.40:8082
ruby demo/artifactory/configure-remote.rb
ruby demo/artifactory/verify-cache.rb
```

Artifactory may take a minute or two to start before `configure-remote.rb` succeeds. Open `http://192.168.5.40:8082/ui/` to see the repository. The local admin username is `admin`; its generated password is in the ignored, private `demo/artifactory/.env` file. The repository data and PostgreSQL data live in Docker volumes and survive a container restart.

`configure-remote.rb` reads the Broadcom registry token from the ignored `vars.yaml` at the repo root. It reads the Broadcom username from the `spring-enterprise-subscription` server in your existing `~/.m2/settings.xml`, or from `BROADCOM_EMAIL`. It changes the default local admin password, backs up Artifactory's configuration under the ignored `demo/artifactory/downloads/` directory, and configures the remote with Bearer authentication. Re-run it after rotating your Broadcom token.

JFrog's individual [Create Repository API](https://docs.jfrog.com/artifactory/reference/createrepository) is Pro-only on this OSS installation. The script uses JFrog's [self-hosted YAML configuration endpoint](https://docs.jfrog.com/administration/reference/patchsystemconfiguration), which works on OSS. It applies only the `spring-enterprise-remote` entry. The source syntax follows JFrog's [repository YAML reference](https://docs.jfrog.com/installation/docs/repositories-configurations-in-artifactory-yaml).

`verify-cache.rb` fetches the Spring Boot 3.4.17.1 parent POM through the remote and compares it to the `spring-enterprise-remote-cache` copy. A matching SHA-256 demonstrates that Artifactory fetched and stored the artifact.

## Point Maven at the cache

Add a mirror to your Maven `settings.xml` (the examples use `localhost`; substitute the Artifactory host). Application Advisor follows Maven mirrors, so with this mirror in place neither Maven nor the advisor CLI needs the `spring-enterprise-subscription` Broadcom server entry; a settings file with only the mirror and its server has been verified to run `build-config get`, `upgrade-plan get`, `patch apply`, and `upgrade-plan apply`:

```xml
<mirrors>
  <mirror>
    <id>spring-enterprise-remote</id>
    <mirrorOf>spring-enterprise-subscription</mirrorOf>
    <url>http://localhost:8082/artifactory/spring-enterprise-remote</url>
  </mirror>
</mirrors>
```

The mirror requires a matching Maven `<server>` with ID `spring-enterprise-remote`, username `admin`, and the generated Artifactory admin password. In a Harness Docker Run step, the Application Advisor template writes the equivalent settings from its `MAVEN_MIRROR_*` inputs, and `demo/scripts/configure-maven.sh` does the same from `ARTIFACTORY_URL` and `ARTIFACTORY_PASSWORD`. Step containers reach the demo host's Artifactory at `http://192.168.5.40:8082`.

The advisor CLI tarball also downloads through the remote, at `com/vmware/tanzu/spring/application-advisor-cli-<variant>/<version>/`. Artifactory OSS cannot answer latest-version searches, and Broadcom publishes no `maven-metadata.xml` for the CLI, so `demo/scripts/install-advisor.sh` pins the version.

Artifactory binds port 8082 to `ARTIFACTORY_BIND_ADDRESS` (loopback by default). It uses the admin account and plain HTTP, so expose it only on a trusted network. The Docker image is pinned to 7.161.26, which includes JFrog's [7.161.20 security fix](https://docs.jfrog.com/releases/docs/jfrog-security-advisories). `JF_JFCONNECT_ENABLED=false` avoids a [known OSS UI startup hang](https://github.com/jfrog/charts/issues/2233).

## Stop and restart

On the Artifactory host, from the directory holding `compose.yaml`:

```bash
docker compose --env-file .env -f compose.yaml down
bash start-local.sh
```

The command above preserves the Docker volumes and cached artifacts. The Git demo reset does not change Artifactory's state.
