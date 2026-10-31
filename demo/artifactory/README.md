# Optional Artifactory OSS mirror

Artifactory OSS can proxy Maven repositories without a paid Artifactory license. Use JFrog's [official Docker Compose package for Artifactory OSS](https://docs.jfrog.com/installation/docs/docker) for a local installation. It is heavier than the Harness runner and may need several GB of memory. Use the `oss` package; JFrog Container Registry (JCR) does not support Maven repositories.

In Artifactory, create a **Maven remote** repository called `spring-enterprise-remote`:

| Setting | Value |
| --- | --- |
| URL | `https://packages.broadcom.com/artifactory/spring-enterprise` |
| Upstream username | Broadcom account email |
| Upstream password | Broadcom registry token |

These credentials live in Artifactory's configuration, not in this repository. A remote repository caches artifacts on first request; it does not copy the complete Broadcom repository. Artifactory's [Maven repository guide](https://docs.jfrog.com/artifactory/docs/maven-repositories) describes remote and virtual repositories.

To route the app's Spring Enterprise Maven requests through your local Artifactory, add a Maven mirror to the same `~/.m2/settings.xml` that has the `spring-enterprise-subscription` server:

```xml
<mirrors>
  <mirror>
    <id>spring-enterprise-remote</id>
    <mirrorOf>spring-enterprise-subscription</mirrorOf>
    <url>http://localhost:8082/artifactory/spring-enterprise-remote</url>
  </mirror>
</mirrors>
```

If the Maven build runs in a Docker container on macOS, replace `localhost` with `host.docker.internal`. If Artifactory requires client authentication, add a Maven `<server>` whose ID is `spring-enterprise-remote` with the Artifactory credentials. Keep the Broadcom server entry too, since Application Advisor uses that identity directly.

Show the mirror working by requesting an enterprise artifact in a build, then opening the `spring-enterprise-remote-cache` repository in Artifactory. The Artifactory UI should show the cached artifact. A regular PetClinic build may resolve only public artifacts and leave this cache empty until Advisor applies an enterprise patch.
