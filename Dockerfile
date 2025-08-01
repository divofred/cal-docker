FROM node:18 AS builder

WORKDIR /calcom

# Copy configuration files
COPY calcom/package.json calcom/yarn.lock calcom/.yarnrc.yml calcom/playwright.config.ts calcom/turbo.json calcom/i18n.json ./
COPY calcom/.yarn ./.yarn
COPY calcom/apps/web ./apps/web
COPY calcom/apps/api/v2 ./apps/api/v2
COPY calcom/packages ./packages
COPY calcom/tests ./tests
COPY scripts ./scripts

# Set environment variables
ARG NEXT_PUBLIC_LICENSE_CONSENT
ARG NEXT_PUBLIC_WEBSITE_TERMS_URL
ARG NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL
ARG CALCOM_TELEMETRY_DISABLED
ARG DATABASE_URL
ARG NEXTAUTH_SECRET=secret
ARG CALENDSO_ENCRYPTION_KEY=secret
ARG MAX_OLD_SPACE_SIZE=2048
ARG NEXT_PUBLIC_API_V2_URL
ARG NEXT_PUBLIC_WEBAPP_URL=https://authentic-education-production.up.railway.app

ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
  NEXT_PUBLIC_API_V2_URL=$NEXT_PUBLIC_API_V2_URL \
  NEXT_PUBLIC_LICENSE_CONSENT=$NEXT_PUBLIC_LICENSE_CONSENT \
  NEXT_PUBLIC_WEBSITE_TERMS_URL=$NEXT_PUBLIC_WEBSITE_TERMS_URL \
  NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL=$NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL \
  CALCOM_TELEMETRY_DISABLED=$CALCOM_TELEMETRY_DISABLED \
  DATABASE_URL=$DATABASE_URL \
  DATABASE_DIRECT_URL=$DATABASE_URL \
  NEXTAUTH_SECRET=${NEXTAUTH_SECRET} \
  CALENDSO_ENCRYPTION_KEY=${CALENDSO_ENCRYPTION_KEY} \
  NODE_OPTIONS=--max-old-space-size=${MAX_OLD_SPACE_SIZE} \
  BUILD_STANDALONE=true \
  NODE_ENV=production

# Install dependencies and build
RUN yarn config set httpTimeout 1200000
RUN yarn install --frozen-lockfile
RUN npx turbo prune --scope=@calcom/web --scope=@calcom/trpc --docker
RUN yarn workspace @calcom/trpc run build
RUN yarn --cwd packages/embeds/embed-core workspace @calcom/embed-core run build
RUN yarn --cwd apps/web workspace @calcom/web run build
RUN chmod +x scripts/replace-placeholder.sh
RUN scripts/replace-placeholder.sh http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER ${NEXT_PUBLIC_WEBAPP_URL}
RUN rm -rf node_modules/.cache .yarn/cache apps/web/.next/cache

FROM node:18 AS runner

WORKDIR /calcom
COPY --from=builder /calcom ./
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
  BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
  NODE_ENV=production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=30s --retries=5 \
  CMD wget --spider https://authentic-education-production.up.railway.app || exit 1

CMD ["/calcom/scripts/start.sh"]