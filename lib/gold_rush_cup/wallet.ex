defmodule GoldRushCup.Wallet do
  @moduledoc false

  use GenServer
  alias GoldRushCup.{Explorer, API}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, [name: __MODULE__])
  end

  def init(_state) do
    {:ok, %{amount: 0, wallet: []}}
  end

  def get_coins(amount) do
    GenServer.call(__MODULE__, {:get_coins, amount})
  end

  def put_coins(coins) do
    GenServer.cast(__MODULE__, {:put_coins, coins})
  end

  def get_balance do
    GenServer.call(__MODULE__, :get_balance)
  end

  def handle_call({:get_coins, amount}, _from, state) do
    if state.amount > amount do
      {return, rest_wallet} = Enum.split(state.wallet, amount)

      {:reply, {:ok, return}, %{state | wallet: rest_wallet, amount: state.amount - amount}}
    else
      {:reply, {:error, :balance_not_enough}, state}
    end
  end

  def handle_call(:get_balance, _from, state) do
    {:reply, {:ok, state.amount}}
  end

  def handle_cast({:put_coins, coins}, state) do
    {:noreply, %{state | wallet: state.wallet ++ coins, amount: (state.amount + Enum.count(coins)) |> IO.inspect}}
  end
end
