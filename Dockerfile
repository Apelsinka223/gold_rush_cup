# Elixir Destiller
FROM elixir:1.11-alpine as build

ARG MIX_ENV=prod
ENV MIX_ENV $MIX_ENV

WORKDIR /app/
COPY . .

RUN apk add --no-cache build-base inotify-tools curl musl-dev openssh

RUN mix local.rebar --force && \
    mix local.hex --force && \
    mix deps.get && \
    mix deps.clean mime --build

RUN cd /app && mix compile
RUN mix release

# Elixir bulb
FROM elixir:1.11-alpine
ARG MIX_ENV=prod
# Add Tini
ENV TINI_VERSION v0.18.1

RUN apk add --no-cache tini

COPY --from=build ./app/_build/$MIX_ENV/rel/gold_rush_cup .

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["sh","-c", "bin/gold_rush_cup start"]
