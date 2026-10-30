# Supabase migrations of this commit + the Supabase CLI that applies them.
# Used by the homelab k8s Job: `supabase db push --db-url ...`, which records
# applied versions in supabase_migrations.schema_migrations.
FROM debian:bookworm-slim

ARG SUPABASE_CLI_VERSION=2.89.1
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && cd /tmp \
  && curl -fsSLO "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_linux_amd64.tar.gz" \
  && curl -fsSLO "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_${SUPABASE_CLI_VERSION}_checksums.txt" \
  && grep " supabase_linux_amd64.tar.gz$" "supabase_${SUPABASE_CLI_VERSION}_checksums.txt" | sha256sum -c - \
  && tar -xzf supabase_linux_amd64.tar.gz -C /usr/local/bin supabase \
  && rm -f /tmp/supabase_*

WORKDIR /work
COPY supabase/ /work/supabase/
USER 1001
ENTRYPOINT ["supabase"]
