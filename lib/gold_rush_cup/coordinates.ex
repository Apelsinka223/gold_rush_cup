defmodule GoldRushCup.License do
  @moduledoc """
  License on digging is a contest entity, needed to have permission on digging
  and is sent with every digging request.

  Needed to be received with a separate request, either free of for coins.
  """

  defstruct [:id, :dig_allowed, :dig_used]
end
