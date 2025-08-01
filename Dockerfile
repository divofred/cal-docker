FROM node:18

WORKDIR /calcom

# Set environment variables
ARG NEXT_PUBLIC_WEBAPP_URL=https://authentic-education-production.up.railway.app
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
  BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
  NODE_ENV=production \
  MAX_OLD_SPACE_SIZE=4096 \
  NODE_OPTIONS=--max-old-space-size=4096

# Copy everything needed for install and build
COPY calcom/package.json calcom/yarn.lock calcom/.yarnrc.yml ./
COPY calcom/.yarn ./.yarn
COPY calcom/apps ./apps
COPY calcom/packages ./packages
COPY calcom/tests ./tests
COPY calcom/i18n.json ./i18n.json
COPY calcom/turbo.json ./turbo.json
COPY calcom/playwright.config.ts ./playwright.config.ts
COPY scripts ./scripts

# Fix permissions
RUN chmod +x scripts/replace-placeholder.sh scripts/start.sh

# Install & build
RUN yarn install --frozen-lockfile
RUN scripts/replace-placeholder.sh http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER $NEXT_PUBLIC_WEBAPP_URL
RUN yarn build

# Cleanup cache to reduce image size
RUN rm -rf node_modules/.cache .yarn/cache apps/web/.next/cache

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=30s --retries=5 \
  CMD wget --spider https://authentic-education-production.up.railway.app || exit 1

CMD ["./scripts/start.sh"]
