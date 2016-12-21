defmodule Cerbas.General do
  @moduledoc false
  import Cerbas
  def sum(a, b) do
    "sum a -> #{inspect a}" |> color_info(:yellow)
    "sum b -> #{inspect b}" |> color_info(:yellow)
    a + b
    rescue
      e ->
        {:error, "bad arguments"}
  end
end
