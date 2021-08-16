defmodule GoldRushCup.Digger do
  @moduledoc false

  use GenServer
  alias GoldRushCup.{TaskSupervisor, API, LicenseHolder, Exchanger}
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_opts) do
    Logger.debug("Digger started #{inspect(self())}")
    {:ok, %{coordinates: []}}
  end

  def dig(coordinates), do: GenServer.cast(__MODULE__, {:dig, coordinates})

  def handle_cast({:dig, coordinates}, state) do
    if state.coordinates == [] do
      send(self(), :dig)
    end

    {:noreply, %{state | coordinates: [coordinates | state.coordinates]}}
  end

  def handle_info(:dig, %{coordinates: []} = state), do: {:noreply, state}

  def handle_info(:dig, state) do
    with max_depth_coordinates = Enum.max_by(state.coordinates, & &1.depth),
         {:ok, license} <- LicenseHolder.get_license(),
         coordinates = %{max_depth_coordinates | depth: max_depth_coordinates.depth + 1},
         %{depth: depth} when depth <= 10 <- coordinates do
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        API.dig(license, coordinates)
      end)

      state = %{state | coordinates: List.delete(state.coordinates, max_depth_coordinates)}

      if state.coordinates != [] do
        send(self(), :dig)
      end

      {:noreply, state}
    else
      %{} ->
        if state.coordinates != [] do
          send(self(), :dig)
        end

        {:noreply, state}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({task_ref, {:ok, [], coordinates}}, strategy) do
    Process.demonitor(task_ref, [:flush])

    if coordinates.depth < 10 do
      GenServer.cast(__MODULE__, {:dig, coordinates})
    end

    {:noreply, strategy}
  end

  def handle_info({task_ref, {:ok, treasure_list, coordinates}}, strategy) do
    Process.demonitor(task_ref, [:flush])
    Logger.debug("Treasure found #{inspect(coordinates)}")
    Exchanger.exchange(treasure_list)
    {:noreply, strategy}
  end

  def handle_info({task_ref, {:error, reason}}, strategy) do
    Process.demonitor(task_ref, [:flush])
    {:stop, reason, strategy}
  end
end
