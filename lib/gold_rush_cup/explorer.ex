defmodule GoldRushCup.Explorer do
  @moduledoc """
  Process of calculation of the coordinates to dig at.
  Explores a map moving by a spiral from borders to the center.

  Is a producer in GenStage chain and has several workers that subscribes at it
  on the application start. Uses ets as a temporary storage.

  On demand returns next coordinates to dig in reply.
  If there is no demand, saves coordinates to ets and sends them on demand.
  """

  use GenStage
  alias GoldRushCup.{TaskSupervisor, API, Digger, ExplorerWorker}
  require Logger

  def start_link(state) do
    GenStage.start_link(__MODULE__, state, name: state.name)
  end

  def init(strategy) do
    Process.flag(:trap_exit, true)

    send(
      self(),
      {:explore, strategy.first_coordinates, hd(strategy.action_list), hd(strategy.size_list)}
    )

    Logger.debug("Explorer started #{inspect(self())}: #{inspect(strategy)}")
    {:producer, Map.put(strategy, :demand, 0), dispatcher: GenStage.DemandDispatcher}
  end

  def handle_info({:explore, coordinates, direction, size}, %{demand: demand} = strategy)
      when demand > 0 do
    with {:ok, next_direction, next_coordinates, next_strategy} <-
           next_move(coordinates, direction, size, strategy) do
      send(self(), {:explore, next_coordinates, next_direction, size})

      {:noreply, [{size, coordinates.x, coordinates.y}],
       %{strategy | demand: strategy.demand - 1}}
    else
      {:error, :stop} ->
        {:noreply, [], %{strategy | demand: strategy.demand - 1}}

      {:error, reason} ->
        {:stop, reason, %{strategy | demand: strategy.demand - 1}}
    end
  end

  def handle_info({:explore, coordinates, direction, size}, strategy) do
    :ets.insert_new(strategy.ets, {{size, coordinates.x, coordinates.y}})

    with {:ok, next_direction, next_coordinates, next_strategy} <-
           next_move(coordinates, direction, size, strategy) do
      send(self(), {:explore, next_coordinates, next_direction, size})
      {:noreply, [], next_strategy}
    else
      {:error, :stop} ->
        {:noreply, [], strategy}

      {:error, reason} ->
        {:stop, reason, strategy}
    end
  end

  @doc """
  After
  """
  def handle_info({task_ref, {:ok, _, area}}, strategy) do
    with {:ok, next_size} <- next_size_by_strategy(strategy, area),
         coordinates = calculate_next_coordinates(area, next_size) do

      Enum.each(coordinates, &:ets.insert_new(strategy.ets, &1))
      {:noreply, [], strategy}
    else
      {:error, reason} ->
        {:stop, reason, strategy}
    end
  end

  defp calculate_next_coordinates(area, next_size) do
    for x <- 0..div(area.size_x, next_size) |> Enum.map(&(&1 * next_size + area.x)),
        y <- 0..div(area.size_x, next_size) |> Enum.map(&(&1 * next_size + area.y)) do
      {{next_size, x, y}}
    end
  end

  defp next_size_by_strategy(strategy, area) do
    strategy.size_list
    |> Enum.find_index(&(&1 == area.size_x))
    |> case do
      nil ->
        {:error, :strategy_size_not_found}

      index ->
        {:ok, Enum.at(strategy.size_list, index + 1)}
    end
  end

  def handle_info({task_ref, {:error, reason}}, strategy) do
    {:stop, reason, strategy}
  end

  def handle_demand(demand, strategy) do
    demanded =
      1..(strategy.demand + demand)
      |> get_demand_from_ets(strategy)

    {:noreply, demanded, %{strategy | demand: strategy.demand + demand - Enum.count(demanded)}}
  end

  defp get_demand_from_ets(demand, strategy) do
    demand
    |> Enum.reduce_while([], fn _, acc ->
      with {_, _, _} = key <- :ets.first(strategy.ets),
           true = :ets.delete(strategy.ets, key) do
        {:cont, [key | acc]}
      else
        :"$end_of_table" ->
          {:halt, acc}
      end
    end)
    |> Enum.filter(& &1)
  end

  defp next_move(
         coordinates,
         direction,
         size,
         %{min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y} = strategy
       )
       when max_x - min_x <= size and max_y - min_y <= size do
    {:error, :stop}
  end

  defp next_move(
         coordinates,
         direction,
         size,
         %{min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y} = strategy
       ) do
    with {:ok, next_direction} <- choose_direction(direction, coordinates, size, strategy),
         next_coordinates = next_coordinates_by_direction(next_direction, coordinates, size),
         next_strategy = next_strategy_by_direction(direction, next_direction, size, strategy) do
      {:ok, next_direction, next_coordinates, next_strategy}
    end
  end

  defp choose_direction(
         direction,
         %{x: x, y: y},
         size,
         %{mix_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y} = strategy
       )
       when (direction == :up and y < min_y + size) or
              (direction == :down and y > max_y - size) or
              (direction == :left and x < min_x + size) or
              (direction == :right and x > max_x - size) do
    strategy.action_list
    |> Enum.find_index(&(&1 == direction))
    |> case do
      nil ->
        {:error, :stratedy_not_found}

      index ->
        {:ok, Enum.at(strategy.action_list, index + 1) || hd(strategy.action_list)}
    end
  end

  defp next_coordinates_by_direction(:up, coordinates, size),
    do: %{coordinates | y: coordinates.y - size}

  defp next_coordinates_by_direction(:down, coordinates, size),
    do: %{coordinates | y: coordinates.y + size}

  defp next_coordinates_by_direction(:left, coordinates, size),
    do: %{coordinates | x: coordinates.x - size}

  defp next_coordinates_by_direction(:right, coordinates, size),
    do: %{coordinates | x: coordinates.x + size}

  defp next_strategy_by_direction(direction, direction, _size, strategy), do: strategy

  defp next_strategy_by_direction(:up, coordinates, size, strategy),
    do: %{strategy | max_y: strategy.max_y - size + 1}

  defp next_strategy_by_direction(:down, coordinates, size, strategy),
    do: %{strategy | min_y: strategy.min_y + size - 1}

  defp next_strategy_by_direction(:left, coordinates, size, strategy),
    do: %{strategy | max_x: strategy.max_x - size + 1}

  defp next_strategy_by_direction(:right, coordinates, size, strategy),
    do: %{strategy | min_x: strategy.min_x + size - 1}

  defp choose_direction(direction, _, _, _), do: {:ok, direction}
end
