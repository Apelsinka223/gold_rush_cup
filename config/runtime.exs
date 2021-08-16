# This file is assigned for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :gold_rush_cup, :api,
  address: System.get_env("ADDRESS", "localhost"),
  port: "8000"
