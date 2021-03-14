defmodule GoldRushCup.ExplorerWorker do
  @moduledoc false

  use GenStage
  alias GoldRushCup.{Explorer, API, Digger}

  def start_link(ets) do
    GenStage.start_link(__MODULE__, ets)
  end

  def init(state) do
    {
      :consumer,
      state,
      subscribe_to: [{Explorer, max_demand: 2, min_demand: 1}]
    }
  end

  def explore do
    case :poolboy.checkout(:explorer_worker, false) do
      :full ->
        Explorer.full()

      worker ->
        GenServer.cast(worker, :explore)
    end
  end

  def handle_events([{size, x, y}], _from, state) do
      case API.explore(%{x: x, y: y}, size) do
        {:ok, 0, _} ->
          :ok

        {:ok, _, %{size_x: 1} = area} ->
           Digger.dig(%{x: area.x, y: area.y, depth: 0})

        {:ok, _, area} = message ->
          send(Process.whereis(Explorer), {nil, message})

       {:error, reason} ->
         :ok
      end

#      :poolboy.checkin(:explorer_worker, self())
      {:noreply, [], state}
#    else
#      [] ->
#        IO.inspect(:race_condition_explorer)
#        :poolboy.checkin(:explorer_worker, self())
#        {:noreply, ets}

#      :"$end_of_table" ->
#        :poolboy.checkin(:explorer_worker, self())
#        {:noreply, ets}
#    end
  end

end
