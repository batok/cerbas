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

  def get_proxied_host_port(server) do
    uri = server |> String.to_atom |> Cerbas.Web.proxy_host
    {port, _} = uri |> String.split(":") |> List.last() |> Integer.parse()
    port
    rescue
      e ->
        {:error, "bad conversions"}

  end  
end
