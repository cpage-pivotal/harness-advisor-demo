# Local Artifactory OSS Maven cache

This demo runs Artifactory OSS and PostgreSQL in Docker, then creates a Maven remote repository named `spring-enterprise-remote`. It points to Broadcom's Spring Enterprise repository and caches artifacts as they are requested. This is an on-demand cache, not a complete copy of the upstream repository.

## Start and configure

From the demo repository root:

```bash
bash demo/artifactory/start-local.sh
ruby demo/artifactory/configure-remote.rb
ruby demo/artifactory/verify-cache.rb
```

Artifactory may take a minute or two to start before `configure-remote.rb` succeeds. Open `http://localhost:8082/ui/` to see the repository. The local admin username is `admin`; its generated password is in the ignored, private `demo/artifactory/.env` file. The repository data and PostgreSQL data live in Docker volumes and survive a container restart.

`configure-remote.rb` reads the Broadcom registry token from the ignored `vars.yaml` at the repo root. It reads the Broadcom username from the `spring-enterprise-subscription` server in your existing `~/.m2/settings.xml`, or from `BROADCOM_EMAIL`. It changes the default local admin password, backs up Artifactory's configuration under the ignored `demo/artifactory/downloads/` directory, and configures the remote with Bearer authentication. Re-run it after rotating your Broadcom token.

JFrog's individual [Create Repository API](https://docs.jfrog.com/artifactory/reference/createrepository) is Pro-only on this OSS installation. The script uses JFrog's [self-hosted YAML configuration endpoint](https://docs.jfrog.com/administration/reference/patchsystemconfiguration), which works on OSS. It applies only the `spring-enterprise-remote` entry. The source syntax follows JFrog's [repository YAML reference](https://docs.jfrog.com/installation/docs/repositories-configurations-in-artifactory-yaml).

`verify-cache.rb` fetches the Spring Boot 3.4.17.1 parent POM through the remote and compares it to the `spring-enterprise-remote-cache` copy. A matching SHA-256 demonstrates that Artifactory fetched and stored the artifact.

## Point Maven at the cache

Add a mirror to your Maven `settings.xml`. Application Advisor follows Maven mirrors, so with this mirror in place neither Maven nor the advisor CLI needs the `spring-enterprise-subscription` Broadcom server entry; a settings file with only the mirror and its server has been verified to run `build-config get`, `upgrade-plan get`, `patch apply`, and `upgrade-plan apply`:

```xml
<mirrors>
  <mirror>
    <id>spring-enterprise-remote</id>
    <mirrorOf>spring-enterprise-subscription</mirrorOf>
    <url>http://localhost:8082/artifactory/spring-enterprise-remote</url>
  </mirror>
</mirrors>
```

The mirror requires a matching Maven `<server>` with ID `spring-enterprise-remote`, username `admin`, and the generated Artifactory admin password. In a Harness Docker Run step, `demo/scripts/configure-maven.sh` writes exactly this from `ARTIFACTORY_URL` and `ARTIFACTORY_PASSWORD`; use `host.docker.internal` in place of `localhost`.

The advisor CLI tarball also downloads through the remote, at `com/vmware/tanzu/spring/application-advisor-cli-<variant>/<version>/`. Artifactory OSS cannot answer latest-version searches, and Broadcom publishes no `maven-metadata.xml` for the CLI, so `demo/scripts/install-advisor.sh` pins the version.

Artifactory is bound to the host's loopback address on port 8082. The Docker image is pinned to 7.161.26, which includes JFrog's [7.161.20 security fix](https://docs.jfrog.com/releases/docs/jfrog-security-advisories). `JF_JFCONNECT_ENABLED=false` avoids a [known OSS UI startup hang](https://github.com/jfrog/charts/issues/2233).

## Stop and restart

```bash
docker compose --env-file demo/artifactory/.env -f demo/artifactory/compose.yaml down
bash demo/artifactory/start-local.sh
```

The command above preserves the Docker volumes and cached artifacts. The Git demo reset does not change Artifactory's state.
