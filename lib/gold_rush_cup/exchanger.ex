defmodule GoldRushCup.Exchanger do
  @moduledoc false

  use GenStage
  alias GoldRushCup.{TaskSupervisor, API, LicenseHolder, Wallet, ExchangerWorker}

  def start_link(_opts) do
    GenStage.start_link(__MODULE__, %{}, [name: __MODULE__])
  end

  def init(_opts) do
    {:producer, %{demand: 0, treasure_list: []}, dispatcher: GenStage.DemandDispatcher}
  end

  def exchange(treasure_list) do
    GenStage.cast(__MODULE__, {:exchange, treasure_list})
  end

  def handle_cast({:exchange, treasure_list}, state) do
#    treasure_list
#    |> Enum.each(fn treasure_id ->
#      # Task.Supervisor.async_nolink(TaskSupervisor, fn ->
#      ExchangerWorker.exchange(treasure_id)
#      #end)
#    end)

    {demanded, rest_treasure_list} =
      if state.demand > 0 and state.treasure_list == [] do
         Enum.split(treasure_list, state.demand)
      else
        {[], treasure_list}
      end
    {:noreply, demanded, %{state | treasure_list: rest_treasure_list ++ state.treasure_list}}
  end


  def handle_demand(demand, state) do
    {demanded, rest_treasure_list} = Enum.split(state.treasure_list, state.demand + demand)

    {
      :noreply,
      demanded,
      %{
        state |
        demand: state.demand + demand - Enum.count(demanded),
        treasure_list: rest_treasure_list
      }
    }
  end
end
