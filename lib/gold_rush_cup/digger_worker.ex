defmodule GoldRushCup.DiggerWorker do
  @moduledoc false

  use GenStage
  alias GoldRushCup.{TaskSupervisor, API, LicenseHolder, Exchanger, Digger}

  def start_link(state) do
    GenStage.start_link(__MODULE__, state, [])
  end

  def init(state) do
#    {:ok, digger_ets}
    {
      :consumer,
      state,
      subscribe_to: [{Digger, max_demand: 2, min_demand: 1}]
    }
  end

  def dig do
    case :poolboy.checkout(:digger_worker, false) do
      :full ->
        Digger.full()

      worker ->
        GenServer.cast(worker, :dig)
    end
  end

  def handle_events([{depth, x, y}], _, state) do
    with {:ok, license} <- LicenseHolder.get_license(),
         coordinates = %{x: x, y: y, depth: depth + 1} do

      case API.dig(license, coordinates) do
        {:ok, [], _} ->
          Digger.dig(coordinates)

        {:ok, treasure_list, coordinates} ->
          Exchanger.exchange(treasure_list)

        {:error, reason} ->
          :ok
      end

#      :poolboy.checkin(:digger_worker, self())
      {:noreply, [], state}
    else
#      [] ->
#        IO.inspect(:race_condition_digger)
#        :poolboy.checkin(:digger_worker, self())
#        {:noreply, digger_ets}

      {:error, reason} ->
#        :poolboy.checkin(:digger_worker, self())
        {:stop, reason, state}

#      :"$end_of_table" ->
#        :poolboy.checkin(:digger_worker, self())
#        {:noreply, digger_ets}
    end
  end
end
