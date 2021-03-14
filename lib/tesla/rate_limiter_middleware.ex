defmodule GoldRushCup.Tesla.RetaLimiterMiddleware do
  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, options) do
    if URI.parse(env.url).path == options[:path] or is_nil(options[:path]) do
      options
      |> check_rate_limit()
      |> case do
        :ok ->
          Tesla.run(env, next)

        :error ->
           Process.sleep(options[:timeout])
           call(env, next, options)
      end
    else
      Tesla.run(env, next)
    end
  end

  defp check_rate_limit(options) do
    case ExRated.check_rate(options[:id], options[:scale], options[:limit]) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        :error
    end
  end
end
