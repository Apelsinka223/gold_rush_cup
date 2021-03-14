defmodule GoldRushCup.ExchangerWorker do
  @moduledoc false

  use GenStage
  alias GoldRushCup.{TaskSupervisor, API, LicenseHolder, Wallet, Exchanger}

  def start_link do
    GenStage.start_link(__MODULE__, %{})
  end

  def init(_opts) do
    {
      :consumer,
      %{},
      subscribe_to: [{Exchanger, max_demand: 2, min_demand: 1}]
    }
  end

  def exchange(treasure_id) do
    worker = :poolboy.checkout(:exchanger_worker, true, 30_000)
    GenServer.cast(worker, {:exchange, treasure_id})
  end

  def handle_events([treasure_id], _,  state) do
    with {:ok, wallet} <- API.exchange_treasure(treasure_id) do

      Wallet.put_coins(wallet)
#      :poolboy.checkin(:exchanger_worker, self())
      {:noreply, [], state}
    else
      {:error, reason} ->
#      :poolboy.checkin(:exchanger_worker, self())
        {:stop, reason, state}
    end
  end
end
