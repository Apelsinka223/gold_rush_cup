defmodule GoldRushCup.ExplorerWorker do
  @moduledoc """
  Exploring minions.
  Subscribes on Explorer process on the application start and makes exploring requests synchronously
  in order not to overwhelm external API, since exploring requests occupies API the most.
  Amount of 10 minions is an effective amount of simultaneously running requests.
  """

  use GenStage
  alias GoldRushCup.{Explorer, API, Digger, Coordinates}
  require Logger

  def start_link(ets) do
    GenStage.start_link(__MODULE__, ets)
  end

  def init(state) do
    Logger.debug("ExplorerWorker started #{inspect(self())}")

    {
      :consumer,
      state,
      subscribe_to: [{Explorer, max_demand: 2, min_demand: 1}]
    }
  end

  def handle_events([{size, x, y}], _from, state) do
    case API.explore(%{x: x, y: y}, size) do
      {:ok, 0, _} ->
        :ok

      {:ok, _, %{size_x: 1} = area} ->
        Digger.dig(%Coordinates{x: area.x, y: area.y, depth: 0})

      {:ok, _, area} = message ->
        send(Process.whereis(Explorer), {nil, message})

      {:error, reason} ->
        :ok
    end

    {:noreply, [], state}
  end
end
