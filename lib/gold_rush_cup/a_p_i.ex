defmodule GoldRushCup.API do
  @moduledoc """
  Integration with the contest API endpoint.

  Swagger documentation: https://github.com/All-Cups/highloadcup/blob/main/goldrush/swagger.yaml
  """

  use Tesla

  alias GoldRushCup.{License, Digger, Wallet, Coordinates}
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

  @spec get_license(list(coin :: string())) :: {:ok, License.t()} | {:error, atom()}
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

  @spec dig(License.t(), Coordinates.t()) ::
          {:ok, [treasure :: String.t()], Coordinates.t()} | {:error, atom()}
  def dig(license, coordinates) do
    with dig_coordinates = %{
           "posX" => coordinates.x,
           "posY" => coordinates.y,
           "depth" => coordinates.depth,
           "licenseID" => license.id
         },
         {:ok, %{status: 200, body: treasure_list}} <- post("/dig/", dig_coordinates) do
      {:ok, treasure_list, coordinates}
    else
      {:error, reason} ->
        Logger.error("Dig error #{reason}")
        {:error, reason}

      {:ok, %{status: 404}} ->
        {:ok, [], coordinates}

      {:ok, %{status: 403}} ->
        Digger.dig(%{coordinates | depth: coordinates.depth - 1})
        {:ok, []}

      {:ok, %{status: 422, body: %{"code" => 1001, "message" => message}}} ->
        [[_, depth]] = Regex.scan(~r/wrong depth: .* \(should be (.*)\)/, message)
        dig(license, %{coordinates | depth: String.to_integer(depth)})

      {:ok, %{status: 422, body: body}} ->
        Logger.error("Dig error #{inspect(%{status: 422, body: body})}")
        {:ok, [], coordinates}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Dig error #{inspect(%{status: status, body: body})}")
        {:error, :wrong_status}
    end
  end

  @spec explore(Coordinates.t(), integer()) :: {:ok, integer(), Coordinates.t()} | {:error, atom()}
  def explore(coordinates, size) do
    with {:ok,
          %{
            status: 200,
            body: %{"amount" => amount, "area" => area}
          }
         } <- post("/explore/", serialize_coordinates(coordinates, size)),
         new_coordinates = parse_coordinates(area) do
      Logger.debug("Explored: #{amount}")
      {:ok, amount, new_coordinates}
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

  defp serialize_coordinates(%{x: x, y: y}, size) do
    %{
      "posX" => x,
      "posY" => y,
      "sizeX" => size || 1,
      "sizeY" => size || 1
    }
  end

  defp parse_coordinates(%{"posX" => x, "posY" => y, "sizeX" => size_x, "sizeY" => size_y}) do
    %{x: x, y: y, size_x: size_x, size_y: size_y}
  end

  @spec exchange_treasure(treasure_id :: String.t()) ::
          {:ok, [coin :: String.t()]} | {:error, atom()}
  def exchange_treasure(treasure_id) do
    with headers = [{Tesla.Middleware.Headers, [{"content-type", "application/json"}]}],
         {:ok, %{status: 200, body: wallet}} <-
           post(Tesla.client(headers), "/cash/", Jason.encode!(treasure_id)) do
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
