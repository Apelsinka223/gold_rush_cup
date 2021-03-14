defmodule GoldRushCup.Explorer do
  @moduledoc false

  use GenStage
  alias GoldRushCup.{TaskSupervisor, API, Digger, ExplorerWorker}

  defmodule GoldRushCup.Coordinates do
    defstruct [:x, :y, :depth]
  end

  defmodule Strategy do
    defstruct [:action_list, :max_x, :max_y, :max_depth, :min_x, :min_y, :min_depth]
  end

  def start_link(state) do
    GenStage.start_link(__MODULE__, state, [name: state.name])
  end

  def init(strategy) do
    Process.flag(:trap_exit, true)
    send(self(), {:explore, strategy.first_coordinates, hd(strategy.action_list), hd(strategy.size_list)})
    {:producer, Map.put(strategy, :demand, 0), dispatcher: GenStage.DemandDispatcher}
  end

  def handle_info({:explore, coordinates, direction, size}, strategy) do
    :ets.insert_new(strategy.ets, {{size, coordinates.x, coordinates.y}})

    with {:ok, next_direction, next_coordinates, next_strategy} <- next_move(coordinates, direction, size, strategy) do
      send(self(), {:explore, next_coordinates, next_direction, size})
      {:noreply, [], next_strategy}
    else
      {:error, :stop} ->
        {:noreply, [], strategy}

      {:error, reason} ->
        {:stop, reason, strategy}
    end
  end

  def handle_info({task_ref, {:ok, _, area}}, strategy) do
    # Process.demonitor(task_ref, [:flush])
     with {:ok, next_size} <-
            (strategy.size_list
             |> Enum.find_index(& &1 == area.size_x)
             |> case do
               nil ->
                 {:error, :strategy_size_not_found}

               index ->
                 {:ok, Enum.at(strategy.size_list, index + 1)}
                end) do

     coordinates =
       for x <- 0..div(area.size_x, next_size) |> Enum.map(& &1 * next_size + area.x),
           y <- 0..div(area.size_x, next_size) |> Enum.map(& &1 * next_size + area.y) do
         {{next_size, x, y}}
       end

      Enum.each(coordinates,  & :ets.insert_new(strategy.ets, &1))
      {:noreply, [], strategy}
    else
       {:error, reason} ->
         {:stop, reason, strategy}
    end
  end

  def handle_info({task_ref, {:error, reason}}, strategy) do
    # Process.demonitor(task_ref, [:flush])
    {:stop, reason, strategy}
  end

  def handle_demand(demand, strategy) do
    demanded =
      1..(strategy.demand + demand)
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

    {:noreply, demanded, %{strategy | demand: (strategy.demand + demand - Enum.count(demanded))}}
  end

  defp next_move(
        coordinates,
        direction,
        size,
        %{min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y} = strategy
      ) when max_x - min_x <= size and max_y - min_y <= size do
    {:error, :stop}
  end

  defp next_move(
        coordinates,
        direction,
        size,
        %{min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y} = strategy
      ) do
    with {:ok, next_direction} <-
         (cond do
           (direction == :up and coordinates.y < min_y + size)
           or (direction == :down and coordinates.y > max_y - size)
           or (direction == :left and coordinates.x < min_x + size)
           or (direction == :right and coordinates.x > max_x - size) ->
             strategy.action_list
             |> Enum.find_index(& &1 == direction)
             |> case do
               nil ->
                 {:error, :stratedy_not_found}

               index ->
                 {:ok, Enum.at(strategy.action_list, index + 1) || hd(strategy.action_list)}
                end

           true ->
             {:ok, direction}
         end),

         next_coordinates =
           (case next_direction do
               :up ->
                 %{coordinates | y: coordinates.y - size}

               :down ->
                 %{coordinates | y: coordinates.y + size}

               :left ->
                 %{coordinates | x: coordinates.x - size}

               :right ->
                 %{coordinates | x: coordinates.x + size}
             end),
         next_strategy =
           (case next_direction do
              ^direction ->
                strategy

              :up ->
                %{strategy | max_y: max_y - size + 1}

              :down ->
                %{strategy | min_y: min_y + size - 1}

              :left ->
                %{strategy | max_x: max_x - size + 1}

              :right ->
                %{strategy | min_x: min_x + size - 1}
            end) do

      {:ok, next_direction, next_coordinates, next_strategy}
    end
  end

  def handle_info(a, state) do
    IO.inspect(a)
    {:noreply, state}
  end


end
