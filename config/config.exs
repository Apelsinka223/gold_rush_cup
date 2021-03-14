# This file is assigned for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config


# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:all]

config :tesla, :adapter, Tesla.Adapter.Hackney
config :tesla, Tesla.Middleware.Logger, format: "$method $url ====> $status / time=$time"

config :ex_rated,
  timeout: 10_000,
  cleanup_rate: 10_000,
  persistent: false,
  name: :ex_rated,
  ets_table_name: :ets_rated_test_buckets

#config :logger,
#       backends: [:console, Sentry.LoggerBackend]

#config :sentry, dsn: "https://91fb935a103b4243915479e95cc73e4c@o547895.ingest.sentry.io/5670771",
#   included_environments: [:prod, :dev],
#   environment_name: Mix.env()

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
