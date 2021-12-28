defmodule GoldRushCup.Exchanger do
  @moduledoc """
  Process of exchange of found treasures to coins.

  Creates an async not linked task for each request to an external API since
  each digging request takes some time and could be dropped by external server
  within the contest rules.

  Collected coins are sent to the Wallet process.
  Errors are no expected here, so unsuccessful request stops the process.
  """

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
