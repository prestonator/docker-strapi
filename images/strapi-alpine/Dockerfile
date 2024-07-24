# BASE
ARG NODE=node
ARG NODE_VERSION=18
FROM ${NODE}:${NODE_VERSION}-alpine AS base-alpine
EXPOSE 1337

FROM base-alpine

RUN mkdir -p /srv/app && chown 1000:1000 -R /srv/app

ARG STRAPI_VERSION=latest

ENV STRAPI_VERSION=$STRAPI_VERSION
RUN yarn global add create-strapi-app@${STRAPI_VERSION}

WORKDIR /srv/app

VOLUME /srv/app

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod 777 /usr/local/bin/docker-entrypoint.sh && ln -s /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["strapi"]
