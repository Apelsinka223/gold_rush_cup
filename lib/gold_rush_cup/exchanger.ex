defmodule GoldRushCup.Exchanger do
  @moduledoc false

  use GenServer
  alias GoldRushCup.{TaskSupervisor, API, LicenseHolder, Wallet}
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_opts) do
    Logger.debug("Exchanger started #{inspect(self())}")
    {:ok, %{}}
  end

  def exchange(treasure_list) do
    GenServer.cast(__MODULE__, {:exchange, treasure_list})
  end

  def handle_cast({:exchange, treasure_list}, state) do
    treasure_list
    |> Enum.each(fn treasure_id ->
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        API.exchange_treasure(treasure_id)
      end)
    end)

    {:noreply, state}
  end

  def handle_info({task_ref, result}, state) do
    with _ = Process.demonitor(task_ref, [:flush]),
         {:ok, wallet} <- result do
      Logger.debug("Treasure cost #{Enum.count(wallet)}")
      Wallet.put_coins(wallet)
      {:noreply, state}
    else
      {:error, reason} ->
        {:stop, reason, state}
    end
  end
end
