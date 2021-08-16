defmodule GoldRushCup.API do
  use Tesla

  alias GoldRushCup.{License, Digger}
  require Logger

  plug(Tesla.Middleware.BaseUrl, base_url())
  plug(Tesla.Middleware.JSON)
  plug(GoldRushCup.Tesla.RetaLimiterMiddleware, id: :api, scale: 10, limit: 10, timeout: 1)

  plug(GoldRushCup.Tesla.RetaLimiterMiddleware,
    id: :explore,
    path: "/explore",
    scale: 10,
    limit: 5,
    timeout: 1
  )

  plug(Tesla.Middleware.Retry,
    delay: 10,
    max_retries: 30,
    max_delay: 10_000,
    should_retry: fn
      {:ok, %{status: status}} when status > 500 ->
        true

      {:ok, %{status: 429}} ->
        Logger.error("429")
        true

      {:ok, _} ->
        false

      {:error, _} ->
        true
    end
  )

  def base_url do
    "http://" <>
      Application.get_env(:gold_rush_cup, :api)[:address] <>
      ":" <>
      Application.get_env(:gold_rush_cup, :api)[:port]
  end

  def get_license(coins \\ []) do
    with {:ok, %{status: 200, body: result_license}} <- post("/licenses/", coins),
         license =
           struct(
             License,
             %{
               id: result_license["id"],
               dig_allowed: result_license["digAllowed"],
               dig_used: result_license["digUsed"]
             }
           ) do
      {:ok, license}
    else
      {:error, reason} ->
        Logger.error("License error #{reason}")
        {:error, reason}

      {:ok, %{status: 402}} ->
        {:error, :not_enough_coins}

      {:ok, %{status: 409}} ->
        {:error, :no_more_licenses}

      {:ok, %{status: status}} ->
        Logger.error("License error #{status}")
        {:error, :wrong_status}
    end
  end

  def dig(license, coordinates) do
    with {time, {:ok, %{status: 200, body: treasure_list}}} <-
           :timer.tc(fn ->
             post(
               "/dig/",
               %{
                 "posX" => coordinates.x,
                 "posY" => coordinates.y,
                 "depth" => coordinates.depth,
                 "licenseID" => license.id
               }
             )
           end) do
      {:ok, treasure_list, coordinates}
    else
      {_, {:error, reason}} ->
        Logger.error("Dig error #{reason}")
        {:error, reason}

      {time, {:ok, %{status: 404}}} ->
        {:ok, [], coordinates}

      {time, {:ok, %{status: 403}}} ->
        Digger.dig(%{coordinates | depth: coordinates.depth - 1})
        {:ok, []}

      {time, {:ok, %{status: 422, body: %{"code" => 1001, "message" => message}}}} ->
        [[_, depth]] = Regex.scan(~r/wrong depth: .* \(should be (.*)\)/, message)
        dig(license, %{coordinates | depth: String.to_integer(depth)})

      {time, {:ok, %{status: 422, body: body}}} ->
        Logger.error("Dig error #{inspect(%{status: 422, body: body})}")
        {:ok, [], coordinates}

      {_, {:ok, %{status: status, body: body}}} ->
        Logger.error("Dig error #{inspect(%{status: status, body: body})}")
        {:error, :wrong_status}
    end
  end

  def explore(coordinates, size) do
    with {:ok, %{status: 200, body: %{"amount" => amount, "area" => area}}} <-
           post(
             "/explore/",
             %{
               "posX" => coordinates.x,
               "posY" => coordinates.y,
               "sizeX" => size || 1,
               "sizeY" => size || 1
             }
           ) do
      {
        :ok,
        amount,
        %{x: area["posX"], y: area["posY"], size_x: area["sizeX"], size_y: area["sizeY"]}
      }
    else
      {:error, reason} ->
        Logger.error("Explore error #{reason}")
        {:error, reason}

      {:ok, %{status: 422}} ->
        {:ok, 0, coordinates}

      {:ok, %{status: status}} ->
        Logger.error("Explore error #{status}")
        {:error, :wrong_status}
    end
  end

  def exchange_treasure(treasure_id) do
    with {:ok, %{status: 200, body: wallet}} <-
           post(
             Tesla.client([{Tesla.Middleware.Headers, [{"content-type", "application/json"}]}]),
             "/cash/",
             Jason.encode!(treasure_id)
           ) do
      {:ok, wallet}
    else
      {:error, reason} ->
        Logger.error("Exchange error #{reason}")
        {:error, reason}

      {:ok, %{status: status}} ->
        Logger.error("Exchange error #{status}")
        {:error, :wrong_status}
    end
  end
end
