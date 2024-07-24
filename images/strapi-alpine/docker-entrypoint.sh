#!/bin/sh
set -ea

if [ "$*" = "strapi" ]; then

  if [ ! -f "package.json" ]; then

    DATABASE_CLIENT=${DATABASE_CLIENT:-sqlite}

    EXTRA_ARGS=${EXTRA_ARGS}

    echo "Using strapi v$STRAPI_VERSION"
    echo "No project found at /srv/app. Creating a new strapi project ..."

    npx create-strapi-app@$STRAPI_VERSION . --no-run --skip-cloud \
      --dbclient=$DATABASE_CLIENT \
      --dbhost=$DATABASE_HOST \
      --dbport=$DATABASE_PORT \
      --dbname=$DATABASE_NAME \
      --dbusername=$DATABASE_USERNAME \
      --dbpassword=$DATABASE_PASSWORD \
      --dbssl=$DATABASE_SSL \
      $EXTRA_ARGS
    
    echo "" >| 'config/server.js'
    echo "" >| 'config/admin.js'
    echo "" >| 'config/middlewares.js'

    cat <<-EOT >> 'config/server.js'
module.exports = ({ env }) => ({
  host: env('HOST', '0.0.0.0'),
  port: env.int('PORT', 1337),
  url: env('PUBLIC_URL', 'http://localhost:1337'),
  app: {
    keys: env.array('APP_KEYS'),
  },
  webhooks: {
    populateRelations: env.bool('WEBHOOKS_POPULATE_RELATIONS', false),
  },
});
EOT

    cat <<-EOT >> 'config/admin.js'
module.exports = ({ env }) => ({
  url: env('ADMIN_URL', 'http://localhost:1337/admin'),
  auth: {
    secret: env('ADMIN_JWT_SECRET'),
  },
  apiToken: {
    salt: env('API_TOKEN_SALT'),
  },
  transfer: {
    token: {
      salt: env('TRANSFER_TOKEN_SALT'),
    },
  },
});
EOT

    cat <<-EOT >> 'config/middlewares.js'
module.exports = ({env}) => ([
  'strapi::logger',
  'strapi::errors',
  {
    name: 'strapi::security',
    config: {
      contentSecurityPolicy: {
        useDefaults: true,
        directives: {
          'connect-src': ["'self'", 'http:', 'https:'],
          'img-src': env('IMG_ORIGIN', "'self',data:,blob:,market-assets.strapi.io").split(','),
          upgradeInsecureRequests: null,
        },
      },
    },
  },
  {
    name: 'strapi::cors',
    config: {
      origin: env('CORS_ORIGIN', '*').split(','),
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
      headers: ['Content-Type', 'Authorization', 'Origin', 'Accept'],
      keepHeaderOnError: true,
    }
  },
  'strapi::poweredBy',
  'strapi::query',
  'strapi::body',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
]);
EOT

  elif [ ! -d "node_modules" ] || [ ! "$(ls -qAL node_modules 2>/dev/null)" ]; then

    if [ -f "yarn.lock" ]; then

      echo "Node modules not installed. Installing using yarn ..."
      yarn install --prod --silent

    else

      echo "Node modules not installed. Installing using npm ..."
      npm install --only=prod --silent

    fi

  fi

  if [ -f "yarn.lock" ]; then

    current_strapi_version="$(yarn list --pattern strapi --depth=0 | grep @strapi/strapi | cut -d @ -f 3)"
    current_strapi_code="$(echo "${current_strapi_version}" | tr -d "." )"
    image_strapi_code="$(echo "${STRAPI_VERSION}" | tr -d "." )"
    if [ "${image_strapi_code}" -gt "${current_strapi_code}" ]; then
      echo "Strapi update v${STRAPI_VERSION} found. Currently using v${current_strapi_version}. Updating using yarn ..."
      yarn add "@strapi/strapi@${STRAPI_VERSION}" "@strapi/plugin-users-permissions@${STRAPI_VERSION}" "@strapi/plugin-i18n@${STRAPI_VERSION}" "@strapi/plugin-cloud@${STRAPI_VERSION}" --prod --silent  || echo "Update failed!"
    fi

  else
    
    current_strapi_version="$(npm list | grep @strapi/strapi | cut -d @ -f 3)"
    current_strapi_code="$(echo "${current_strapi_version}" | tr -d "." )"
    image_strapi_code="$(echo "${STRAPI_VERSION}" | tr -d "." )"
    if [ "${image_strapi_code}" -gt "${current_strapi_code}" ]; then
      echo "Strapi update v${STRAPI_VERSION} found. Currently using v${current_strapi_version}. Updating using npm ..."
      npm install @strapi/strapi@"${STRAPI_VERSION}" @strapi/plugin-users-permissions@"${STRAPI_VERSION}" @strapi/plugin-i18n@"${STRAPI_VERSION}" @strapi/plugin-cloud@"${STRAPI_VERSION}" --only=prod --silent  || echo "Update failed!"
    fi

  fi

  if [ -f "yarn.lock" ]; then

    if ! grep -q "\"react\"" package.json; then
      echo "Adding React and Styled Components with yarn..."
      yarn add "react@^18.0.0" "react-dom@^18.0.0" "react-router-dom@^5.3.4" "styled-components@^5.3.3" --prod --silent || echo "Adding React and Styled Components failed!"
    fi

  else

    if ! grep -q "\"react\"" package.json; then
      echo "Adding React and Styled Components with npm..."
      npm install react@"^18.0.0" react-dom@"^18.0.0" react-router-dom@"^5.3.4" styled-components@"^5.3.3" --only=prod --silent || echo "Adding React and Styled Components failed!"
    fi

  fi

  BUILD=${BUILD:-false}

  if [ "$BUILD" = "true" ]; then

    if [ -f "yarn.lock" ]; then

      echo "Building strapi admin using yarn ..."
      yarn build

    else

      echo "Building strapi admin using npm ..."
      npm run build

    fi

  fi

  if [ "$NODE_ENV" = "production" ]; then
    STRAPI_MODE="start"
  elif [ "$NODE_ENV" = "development" ]; then
    STRAPI_MODE="develop"
  fi

  echo "Starting your app (with ${STRAPI_MODE:-develop})..."

  exec yarn "${STRAPI_MODE:-develop}"

else
  exec "$@"
fi
