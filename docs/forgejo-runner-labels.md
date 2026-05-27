# Forgejo Runner Label Mapping

The CI workflow in `.forgejo/workflows/ci.yml` intentionally schedules the
current monorepo job with:

```yaml
runs-on: ubuntu-latest
```

Forgejo Actions does not make that label usable by itself. The repository-owned
runner must advertise a concrete label mapping that tells Forgejo which
execution backend and default job image should handle jobs requesting
`ubuntu-latest`.

The current Compose-managed runner in `e2e/docker-compose.yml` owns that
mapping:

```yaml
command:
  - /bin/forgejo-runner
  - --config
  - /etc/forgejo-runner/config.yml
  - daemon
  - --url
  - ${FORGEJO_RUNNER_URL:-http://forgejo:3000/}
  - --uuid
  - ${FORGEJO_RUNNER_UUID:-38646461-3231-3539-3432-383533316265}
  - --token-url
  - file:///run/secrets/forgejo-runner-token
  - --label
  - ubuntu-latest:docker://docker.io/library/node:22-bookworm
```

This makes jobs with `runs-on: ubuntu-latest` execute in the
`docker.io/library/node:22-bookworm` job container. Node 22 is intentional for
the current web/pnpm-focused monorepo CI path.

Do not replace the mapping with a bare label such as `ubuntu-latest` or
`ubuntu-latest:host`. In a Docker-backed or Docker-in-Docker runner setup, a
bare label can make the runner look for a container image literally named
`ubuntu-latest` or run jobs on the wrong long-lived surface.

## Operator Checks

After runner or DIND maintenance:

1. Confirm `e2e/docker-compose.yml` still maps
   `ubuntu-latest:docker://docker.io/library/node:22-bookworm`.
2. Confirm `.forgejo/workflows/ci.yml` still uses `runs-on: ubuntu-latest` for
   the current web/Node job.
3. Restart the `forgejo-runner` service so it advertises the mapping:

   ```bash
   docker compose -f e2e/docker-compose.yml --profile ci up -d forgejo-runner
   ```

4. In the Forgejo runner admin view, confirm the runner advertises
   `ubuntu-latest`.
5. Trigger CI and confirm the job starts a `node:22-bookworm` container instead
   of waiting for a nonexistent `ubuntu-latest` image/container.

If the runner is ever registered outside this Compose service, use the same
label mapping during registration:

```bash
forgejo-runner register \
  --no-interactive \
  --instance "$FORGEJO_INSTANCE_URL" \
  --token "$FORGEJO_RUNNER_TOKEN" \
  --name "$FORGEJO_RUNNER_NAME" \
  --labels "ubuntu-latest:docker://docker.io/library/node:22-bookworm"
```

Do not commit the registration token, generated `.runner` file, or any copied
secret value. The Compose service reads the runner token from
`${FORGEJO_RUNNER_TOKEN_FILE:-./.runtime/forgejo-runner/token}` and mounts it as
a container secret file.

## Relationship To Verdaccio

The label mapping only selects the job container. The job container still needs
to reach the repository-owned Verdaccio registry. Keep the runner/DIND network
contract documented in [`dependency-management.md`](dependency-management.md):
the external `forgejo-dind` container must be attached to
`medichain-npm-cache-only`, and the workflow must keep the registry variables
pointed at `http://medichain-verdaccio:4873/`.

Reference: Forgejo runner labels use the
`<label-name>:<label-type>://<default-image>` structure documented in the
Forgejo runner configuration guide:
https://forgejo.org/docs/latest/admin/actions/configuration/#choosing-labels
