# apps/web as a plain Node server (Nitro node-server output in .output/),
# instead of the Vercel/Cloudflare deployments upstream uses.
# VITE_* values are inlined at build time, so they are build args.
FROM node:24-bookworm-slim AS build

ARG VITE_APP_URL
ARG VITE_API_URL
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ARG VITE_APP_VERSION
ENV VITE_APP_URL=$VITE_APP_URL \
    VITE_API_URL=$VITE_API_URL \
    VITE_SUPABASE_URL=$VITE_SUPABASE_URL \
    VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY \
    VITE_APP_VERSION=$VITE_APP_VERSION \
    NITRO_PRESET=node-server \
    CI=true

RUN corepack enable
WORKDIR /src
COPY . .
RUN pnpm install --frozen-lockfile
RUN pnpm -F ui build && pnpm -F web build

FROM node:24-bookworm-slim AS runtime
ENV NODE_ENV=production PORT=3000 HOST=0.0.0.0
WORKDIR /app
COPY --from=build /src/apps/web/.output /app/.output
USER 1000
EXPOSE 3000
CMD ["node", ".output/server/index.mjs"]
