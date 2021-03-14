defmodule GoldRushCup.API do
  use Tesla

  alias GoldRushCup.License

  plug Tesla.Middleware.BaseUrl, base_url()
  plug Tesla.Middleware.JSON
#  plug Tesla.Middleware.Logger, log_level: :info
  plug Tesla.Middleware.KeepRequest
  plug Tesla.Middleware.Retry,
    delay: 100,
    max_retries: 30,
    max_delay: 10_000,
    should_retry: fn
      {:ok, %{status: status}} when status > 500 ->
        true
      {:ok, %{status: 429}} ->
        IO.inspect(429)
        true
      {:ok, _} ->
        false
      {:error, _} ->
        true
    end

#  plug GoldRushCup.Tesla.RetaLimiterMiddleware, id: :dig, path: "/dig/", scale: 20, limit: 1, timeout: 11
  plug GoldRushCup.Tesla.RetaLimiterMiddleware, id: :explore, path: "/explore/", scale: 50, limit: 1, timeout: 10
  plug GoldRushCup.Tesla.RetaLimiterMiddleware, id: :all, scale: 10, limit: 1, timeout: 1

  def base_url do
    "http://" <>
      Application.get_env(:gold_rush_cup, :api)[:address] <>
      ":" <>
      Application.get_env(:gold_rush_cup, :api)[:port]
  end

  def get_license(coins \\ []) do
    with {:ok, %{status: 200, body: result_license}} <- post("/licenses/", coins),
#    with {:ok, %{status: 200, body: result_license}} <- {:ok, %{status: 200, body: %{"id" => "1", "digAllowed" => 4, "digUsed" => 0}}},
         license = struct(
               License,
               %{id: result_license["id"], dig_allowed: result_license["digAllowed"], dig_used: result_license["digUsed"]}
             ) do
#      IO.inspect(result_license, label: :result_license)
#      IO.inspect(license, label: :license)
      {:ok, license}
    else
      {:error, reason} ->
        IO.inspect(reason, label: :license_error)
        {:error, reason}

      {:ok, %{status: 402}} ->
        IO.inspect(402, label: :license_error)
        {:error, :not_enough_coins}

      {:ok, %{status: 409}} ->
        IO.inspect(409, label: :license_error)
        {:error, :no_more_licenses}

      {:ok, %{status: status}}->
        IO.inspect(status, label: :license_error)
        {:error, :wrong_status}
    end
  end

  def dig(license, coordinates) do
    with {time, {:ok, %{status: 200, body: treasure_list}}}
           <- :timer.tc(fn -> post(
                "/dig/",
                %{
                  "posX" => coordinates.x,
                  "posY" => coordinates.y,
                  "depth" => coordinates.depth,
                  "licenseID" => license.id
                }
              )end)  do

#<- {:ok, %{status: 200, body: Enum.random([[], ["1"]])}} do

#      IO.inspect(treasure_list)
      {:ok, treasure_list, coordinates}
    else
      {_, {:error, reason}} ->
        IO.inspect(reason, label: :dig_error)
        {:error, reason}

      {time, {:ok, %{status: 404}}}->
        {:ok, [], coordinates}

      {time, {:ok, %{status: 422, body: %{"code" => 1001, "message" => message}}}}->
       [[_, depth] | _] = Regex.scan(~r/wrong depth: .* \(should be (.*)\)/, message)
       dig(license, %{coordinates | depth: String.to_integer(depth)})

      {time, {:ok, %{status: 422, body: body}}}->
       IO.inspect(%{status: 422, body: body}, label: :dig_error)
       {:ok, [], coordinates}

      {_, {:ok, %{status: status, body: body}}} ->
        IO.inspect(%{status: status, body: body}, label: :dig_error)
        {:error, :wrong_status}
    end
  end

  def explore(coordinates, size) do
    with {:ok, %{status: 200, body: %{"amount" => amount, "area" => area}}}
         <- post(
              "/explore/",
              %{
                "posX" => coordinates.x,
                "posY" => coordinates.y,
                "sizeX" => size || 1,
                "sizeY" => size || 1,
              }
            ) do
#    <- {:ok, %{status: 200, body: %{"amount" => Enum.random([0, 1]), area: %{"posX" => coordinates.x, "posY" => coordinates.y}}}} do

#      IO.inspect(coordinates, label: :explore)
#      if amount > 0, do: IO.inspect(amount, label: :amount)
      {:ok, amount, %{x: area["posX"], y: area["posY"], size_x: area["sizeX"], size_y: area["sizeY"]}}
    else
      {:error, reason} ->
        IO.inspect(reason, label: :explore_error)
        {:error, reason}

      {:ok, %{status: 422}} ->
#        IO.inspect(coordinates, label: :explore_wrong_coordinates)
        {:ok, 0, coordinates}

      {:ok, %{status: status}} ->
        IO.inspect(status, label: :explore_error)
        {:error, :wrong_status}
    end
  end

  def exchange_treasure(treasure_id) do
   with {:ok, %{status: 200, body: wallet}} <- post(Tesla.client([{Tesla.Middleware.Headers, [{"content-type", "application/json"}]}]), "/cash/", Jason.encode!(treasure_id)) do
#    with {:ok, %{status: 200, body: wallet}} <- {:ok, %{status: 200, body: nil}} do

      {:ok, wallet}
    else
      {:error, reason} ->
        IO.inspect(reason, label: :exchange_error)
        {:error, reason}

      {:ok, %{status: status}}->
        IO.inspect(status, label: :exchange_error)
        {:error, :wrong_status}
    end
  end
end
