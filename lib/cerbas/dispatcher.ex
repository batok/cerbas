defmodule Cerbas.Dispatcher do
  @moduledoc false
  import Cerbas

  @api_timeout Application.get_env(:cerbas, :api_timeout)
  @api_valid_sources Application.get_env(:cerbas, :api_valid_sources)
  @api_valid_users Application.get_env(:cerbas, :api_valid_sources)

  def dispatch({func, args, source, user}) 
    when is_binary(func)
    when is_map(args)
    when is_binary(source)
    when is_binary(user) do
    if source in @api_valid_users do
      dispatch({func, args, source})
    else
      {:error, "cerbas authorization - invalid user"}
    end
  end

  def dispatch({func, args, source}) 
    when is_binary(func)
    when is_map(args)
    when is_binary(source) do
    if source in @api_valid_sources do
      dispatcher({func, args})
    else
      {:error, "cerbas authorization - invalid source"}
    end
  end

  def dispatch(_whatever) , do: {:error, "bad call"}

  defp dispatcher({func, args}) do
    atom = String.to_atom(func)
    {module, fun, par, async} =
    case atom do
      :hello -> {__MODULE__, :"hello_world", nil, false}
      :asyncfunc -> {__MODULE__, nil, nil, true}
      :withargs -> {__MODULE__, :"func_with_arguments", "foo", false}
      :witherror -> {__MODULE__, :"func_with_error", nil, false}
      :sum -> {Cerbas.General, nil, "a b", false}
      :slow -> {__MODULE__, :"func_slow", nil, false}
      :halt -> {__MODULE__, nil, "delay", true}
      _ -> {:nomatch, nil, nil, false}
    end
    if module != :nomatch do
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
        if async do
          #spawn_link(fn -> apply(module1, fun1, params) end)
          pid = spawn_link(module1, fun1, params) 
          "Spawning #{inspect pid}" |> color_info(:yellow)
          ""
        else
          task = Task.async(module1, fun1, params)
          #receive do
          #  {_, msg} -> 
          #    "#{inspect(msg)}" |> color_info(:yellow)
          #    msg
          #  _ -> {:error, "strange error"}
          #after 
          #  @api_timeout -> {:error, "timeout"}
          #end
          case Task.yield(task, @api_timeout) do
            {:ok, val} -> 
              "#{inspect val}" |> color_info(:yellow)
              val
            _ ->
              Task.shutdown(task)
              {:error, "timeout"}
          end

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
