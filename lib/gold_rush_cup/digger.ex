defmodule GoldRushCup.Digger do
  @moduledoc false

  use GenStage
  alias GoldRushCup.{TaskSupervisor, API, LicenseHolder, Exchanger, DiggerWorker}

  def start_link(digger_ets) do
    GenStage.start_link(__MODULE__, digger_ets, [name: __MODULE__])
  end

  def init(digger_ets) do
    Process.flag(:trap_exit, true)
    {:producer, %{ets: digger_ets, demand: 0}, dispatcher: GenStage.DemandDispatcher}
#    {:ok, digger_ets}
  end

  def dig(coordinates), do: GenStage.cast(__MODULE__, {:dig, coordinates})

  def full, do: GenServer.cast(__MODULE__, :full)

  def handle_cast({:dig, coordinates}, state) do
    if state.demand > 0 and :ets.lookup(state.ets, {coordinates.depth, coordinates.x, coordinates.y}) == [] do
       {:noreply, [{coordinates.depth, coordinates.x, coordinates.y}], state}
    else
      :ets.insert_new(state.ets, {{coordinates.depth, coordinates.x, coordinates.y}})
      |> case do
          true ->
            :ok
  #          DiggerWorker.dig()

          false ->
            IO.inspect({coordinates.depth, coordinates.x, coordinates.y}, label: :duplicate)
         end

      {:noreply, [], state}
    end
  end

  def handle_demand(demand, state) do
    demanded =
      1..(state.demand + demand)
      |> Enum.reduce_while([], fn _, acc ->
           with {_, _, _} = key <- :ets.last(state.ets),
                true = :ets.delete(state.ets, key) do
             {:cont, [key | acc]}
           else
             :"$end_of_table" ->
               {:halt, acc}
           end
         end)
     |> Enum.filter(& &1)

    {:noreply, demanded, %{state | demand: state.demand + demand - Enum.count(demanded)}}
  end

  def handle_cast(:full, digger_ets) do
    Process.send_after(self(), :check_status, 100)
    {:noreply, digger_ets}
  end

  def handle_info(:check_status, digger_ets) do
    case :poolboy.status(:digger_worker) do
    {:ready, free, _, _} ->
      count = :ets.tab2list(digger_ets) |> Enum.count()
      Enum.each(1..min(count, free), fn _ -> DiggerWorker.dig() end)

        if count > free do
          Process.send_after(self(), :check_status, 100)
        end
      _ ->
        Process.send_after(self(), :check_status, 100)
    end

    {:noreply, digger_ets}
  end

  def handle_info({:DOWN, _, _} = a, state) do
    IO.inspect(a)
    {:noreply, state}
  end
end
