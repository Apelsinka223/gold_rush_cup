defmodule GoldRushCup.LicenseHolder do
  @moduledoc """
  Process that handles all provided licenses, monitors license expiration and pre-orders
  a license in advance.

  Has a simple algorithm of figuring out license cost and remembers it (since it can change).

  Can handle the case when it is out of licenses and keep incoming requests from the Digger.
  """

  use GenServer
  alias GoldRushCup.{TaskSupervisor, API, Wallet}
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_opts) do
    Logger.debug("LicenseHolder started #{inspect(self())}")
    {:ok, %{licenses: [], callers: [], cost: 1}, {:continue, :start}}
  end

  def get_license do
    GenServer.call(__MODULE__, :get_license, :infinity)
  end

  def save_cost(cost) do
    GenServer.cast(__MODULE__, {:save_cost, cost})
  end

  def handle_continue(:start, state) do
    send(self(), :request_new_license)

    for i <- 0..8 do
      send(self(), :request_new_license)
    end

    {:noreply, state}
  end

  def handle_info(:request_new_license, state) do
    with {:ok, coins} <- Wallet.get_coins(state.cost) do
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        API.get_license(coins)
      end)

      {:noreply, state}
    else
      {:error, :balance_not_enough} ->
        Task.Supervisor.async_nolink(TaskSupervisor, fn ->
          API.get_license([])
        end)

        Logger.debug("Balance not enough")

        {:noreply, state}
    end
  end

  def handle_info({task_ref, {:error, :not_enough_coins}}, state) do
    Logger.debug("Not enough coins #{state.cost}")
    Process.demonitor(task_ref, [:flush])
    send(self(), :request_new_license)
    {:noreply, %{state | cost: state.cost + 1}}
  end

  def handle_info({task_ref, {:error, :no_more_licenses}}, state) do
    Process.demonitor(task_ref, [:flush])
    Logger.debug("No more licenses")
    {:noreply, state}
  end

  def handle_info({task_ref, {:error, reason}}, state) do
    Process.demonitor(task_ref, [:flush])
    {:stop, reason, state}
  end

  def handle_info({task_ref, {:ok, license}}, %{licenses: licenses, callers: []} = state) do
    Process.demonitor(task_ref, [:flush])
    Logger.debug("New license #{inspect(license)}")
    {:noreply, %{state | licenses: licenses ++ [license]}}
  end

  def handle_info({task_ref, {:ok, license}}, %{licenses: licenses, callers: callers} = state) do
    Process.demonitor(task_ref, [:flush])

    {send_to_callers, rest_callers} = Enum.split(callers, license.dig_allowed)
    Enum.each(send_to_callers, &GenServer.reply(&1, {:ok, license}))

    count = Enum.count(send_to_callers)

    if rest_callers != [] do
      Logger.debug("License expired #{inspect(license)}")
      send(self(), :request_new_license)
    end

    if count < license.dig_allowed do
      license = %{license | dig_used: license.dig_used + count}

      {:noreply, %{state | callers: [], licenses: [license | licenses]}}
    else
      {:noreply, %{state | callers: rest_callers, licenses: licenses}}
    end
  end

  @doc """
  The case when there is no licenses left, process keeps call and once it receives a license -
  sends a replies to all callers.
  """
  def handle_call(:get_license, from, %{licenses: []} = state) do
    {:noreply, %{state | callers: [from | state.callers]}}
  end

  def handle_call(:get_license, _from, %{licenses: licenses} = state) do
    with [license | rest_licenses] <- licenses,
         license = %{license | dig_used: license.dig_used + 1} do
      if license.dig_used == license.dig_allowed do
        Logger.debug("License expired #{inspect(license)}")
        send(self(), :request_new_license)
        {:reply, {:ok, license}, %{state | licenses: rest_licenses}}
      else
        {:reply, {:ok, license}, %{state | licenses: [license | rest_licenses]}}
      end
    else
      [] ->
        {:stop, :license_not_found, state}
    end
  end

  def handle_info(:send_license, %{licenses: []} = state) do
    Process.send_after(self(), :send_license, 500)
    {:noreply, state}
  end
end
