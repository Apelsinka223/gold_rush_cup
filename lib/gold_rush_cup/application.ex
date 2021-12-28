defmodule GoldRushCup.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    explorer_ets = :ets.new(:explorer, [:ordered_set, :public])

    children =
      [
        {Task.Supervisor, name: GoldRushCup.TaskSupervisor},
        GoldRushCup.Digger,
        GoldRushCup.Wallet,
        GoldRushCup.LicenseHolder,
        %{
          id: GoldRushCup.Explorer,
          start:
            {GoldRushCup.Explorer, :start_link,
             [
               %{
                 action_list: [:right, :down, :left, :up],
                 min_y: 1,
                 min_x: 0,
                 max_y: 3499,
                 max_x: 3499,
                 first_coordinates: %{x: 0, y: 0, depth: 0},
                 size_list: [100, 10, 1],
                 name: GoldRushCup.Explorer,
                 ets: explorer_ets
               }
             ]}
        },
        Enum.map(
          # ended up with 10 as the most effective amount of workers for productive exploring
          # as well as not overloading available contest CPU and not idle because of requests
          # rate limit
          0..9,
          &%{
            id: "GoldRushCup.ExplorerWorker" <> to_string(&1),
            start: {GoldRushCup.ExplorerWorker, :start_link, [nil]}
          }
        ),
        GoldRushCup.Exchanger
      ]
      |> List.flatten()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_all, name: GoldRushCup.Supervisor, max_restarts: 0]
    Supervisor.start_link(children, opts)
  end
end
