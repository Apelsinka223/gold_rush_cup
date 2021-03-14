defmodule GoldRushCup.MixProject do
  use Mix.Project

  def project do
    [
      app: :gold_rush_cup,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :poolboy],
      mod: {GoldRushCup.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.4.0"},
      {:hackney, "~> 1.17.0"},
      {:jason, ">= 1.0.0"},
      {:ex_rated, "~> 1.2"},
      {:poolboy, "~> 1.5.1"},
      {:castore, "~> 0.1.0"},
      {:mint, "~> 1.0"},
      {:gen_stage, "~> 1.0"}
    ]
  end
end
