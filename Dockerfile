# -----------------------------------------------------------------------------
FROM node:14-alpine as base
# -----------------------------------------------------------------------------

# Define the base directory and install common npm packages
WORKDIR /app/

# Copy the yarn workspace lockfile & install runtime dependencies
# This lockfile contains all dependencies (see yarn workspaces), including those for client & api
COPY package.json yarn.lock ./
RUN yarn install --production --frozen-lockfile --non-interactive --network-timeout 1000000



# -----------------------------------------------------------------------------
FROM base as api-builder
# -----------------------------------------------------------------------------

# Install build dependencies
WORKDIR /app/packages/api
COPY ./packages/api/package.json ./
RUN yarn install --production --frozen-lockfile --non-interactive --prefer-offline --ignore-engines --network-timeout 1000000

# Add component source to project 
COPY ./packages/api/ .

# Build the api
RUN yarn build


# -----------------------------------------------------------------------------
FROM base as api-dist
# -----------------------------------------------------------------------------

EXPOSE 5000
ENV PORT=5000 

WORKDIR /app/packages/api

# Update installed binraies to latest (fixes security vulnerabilities)
# - https://app.snyk.io/vuln/SNYK-ALPINE311-APKTOOLS-1534687
RUN apk add --upgrade \
    apk-tools

# Copy api runtime dependencies
# Due to use of yarn workspaces, this includes dependencies of all packages (including client and api)
# We might consider using yarn 2 CLI for better workspace dependency management,
# or not using workspaces at all, to avoid shipping irrelevant dependencies with our API
COPY --chown=node:node --from=api-builder /app/node_modules /app/node_modules
COPY --chown=node:node --from=api-builder /app/packages/api/node_modules ./node_modules
COPY --chown=node:node --from=api-builder /app/packages/api/dist ./

# Switch to non-root 'node' user for security reasons.
# We also explicitly grant access to the app folder
RUN chown -R node:node /app/
USER node

ENTRYPOINT [ "node", "index.js" ]
