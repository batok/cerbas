defmodule Cerbas.Dispatcher do
  @moduledoc false
  import Cerbas

  @api_timeout Application.get_env(:cerbas, :api_timeout)
  @api_valid_sources Application.get_env(:cerbas, :api_valid_sources)
  @api_valid_users Application.get_env(:cerbas, :api_valid_sources)
  @echo Application.get_env(:cerbas, :echo)

  def dispatch({func, args, source, user, {cache_key}}) 
    when is_binary(func)
    when is_map(args)
    when is_binary(source)
    when is_binary(user) do
    if source in @api_valid_users do
      dispatch({func, args, source, {cache_key}})
    else
      {:error, "cerbas authorization - invalid user"}
    end
  end

  def dispatch({func, args, source, {cache_key}}) 
    when is_binary(func)
    when is_map(args)
    when is_binary(source) do
    if source in @api_valid_sources do
      dispatcher({func, args, cache_key})
    else
      {:error, "cerbas authorization - invalid source"}
    end
  end

  def dispatch(_whatever) , do: {:error, "bad call"}

  defp mapping(atom) do
    "mapping #{atom}" |> color_info(:yellow)
    case atom do
      :hello -> {__MODULE__, :"hello_world", nil, false, 20}
      :asyncfunc -> {__MODULE__, nil, nil, true, 0}
      :withargs -> {__MODULE__, :"func_with_arguments", "foo", false, 0}
      :witherror -> {__MODULE__, :"func_with_error", nil, false, 0}
      :sum -> {Cerbas.General, nil, "a b", false, 0}
      :proxiedhostport -> {Cerbas.General, :"get_proxied_host_port", "server", false, 0}
      :slow -> {__MODULE__, :"func_slow", nil, false, 0}
      :echo -> @echo
      :halt -> {__MODULE__, nil, "delay", true, 0}
      _ -> {:nomatch, nil, nil, false, 0}
    end
  end

  def cache_seconds(atom) when is_atom(atom) do
    mapping(atom) |> elem(4)
  end

  defp dispatcher({func, args, cache_key}) do
    atom = String.to_atom(func)
    {module, fun, par, async, cache} = mapping(atom)
    if module != :nomatch do
      cached_content =
      if cache > 0 and async == false do
        case get_cached_value(cache_key) do
          "" -> ""
          v -> 
            decoded = Poison.decode!(v)
            case decoded do
              %Response{status: "ok", data: content} -> 
                "Cache content found!" |> color_info(:yellow) 
                content
              _ -> ""
            end
        end        
      else
        ""
      end
      module1 = module
      fun1 = if fun == nil, do: atom, else: fun
      params = 
      if par == nil do
        []
      else
        for x <- String.split(par, " ") do
          args[x]
        end
      end
      if nil in params do 
        "Invalid arguments for func #{func}" |> color_info(:red) 
        {:error, "invalid arguments"}
      else 
        if fun1 in (apply(module1, :module_info, [:exports]) |> Keyword.keys()) do 
          if async do
            pid = spawn_link(module1, fun1, params) 
            "Spawning #{inspect pid}" |> color_info(:yellow)
            ""
          else
            if cached_content == "" do
              task = Task.async(module1, fun1, params)
              case Task.yield(task, @api_timeout) do
                {:ok, val} -> 
                  "#{inspect val}" |> color_info(:yellow)
                  val
                _ ->
                  Task.shutdown(task)
                  {:error, "timeout"}
              end
            else
              cached_content
            end

          end
        else
          fu = Atom.to_string(fun1) 
          "Invalid function {fu}" |> color_info(:red) 
          {:error, "invalid function"}
        end
      end
    else
      "Undefined function" |> color_info(:red)
      {:error, "Undefined function"}
    end
    rescue
      e -> 
        "Error dispatching: #{inspect e}" |> color_info(:red)
        {:error, "error"}
  end

  def hello_world do 
    "hello world!"
    |> color_info(:yellow)
  end

  def func_with_arguments(foo) do
    foo
  end

  def func_with_error, do: {:error, "unexpected error"}

  def func_slow do
    :timer.sleep 6000
    %{"foo" => "bar"}
  end

  def asyncfunc, do: "async display" |> color_info(:yellow)

  def halt(delay) do
    "CERBAS will stop in #{delay} milliseconds" |> color_info(:green)
    :timer.sleep delay
    Agent.update(reg_tuple("halt"), &(not &1)) 
    ""
  end
end
