defmodule CerbasTest do
  use ExUnit.Case, async: true
  doctest Cerbas

  def get_port() do
    Application.get_env(:cerbas, :proxy_target_tornado)
    |> String.split(":") 
    |> List.last()
    |> Integer.parse
    |> elem(0)
    rescue 
      e -> 0
  end

  test "hellox world" do
    assert(
     Cerbas.Dispatcher.dispatch({"hellox", "foo", "bar", {nil}})
     ==
     {:error, "Undefined function"}
    )
  end

  test "hello world" do
    assert(
     Cerbas.Dispatcher.dispatch({"hello", %{}, "tom", {nil}})
     ==
     "hello world!"
    )
  end

  test "async func" do
    assert(
     Cerbas.Dispatcher.dispatch({"asyncfunc", %{}, "tom", {nil}})
     ==
     ""
    )
  end

  test "function with arguments" do
    assert(
     Cerbas.Dispatcher.dispatch({"withargs", %{"foo" => "bar"}, "tom", {nil}})
     ==
     "bar"
    )
  end

  test "function with error" do
    assert(
     Cerbas.Dispatcher.dispatch({"witherror", %{}, "tom", {nil}})
     ==
     {:error, "unexpected error"}
    )
  end

  test "function from other module 1" do
    assert(
     Cerbas.Dispatcher.dispatch({"sum", %{"a" => 1, "b" => 2}, "tom", {nil}})
     ==
     3
    )
  end

  test "function from other module 2" do
    assert(
     Cerbas.Dispatcher.dispatch({"sum", %{"a" => "x", "b" => 2}, "tom", {nil}})
     ==
     {:error, "bad arguments"}
    )
  end

  test "function proxiedhostport" do
    assert(
     Cerbas.Dispatcher.dispatch({"proxiedhostport", %{"server" => "tornado"}, "tom", {nil}})
     ==
     get_port()
    )
  end

  test "halt in 5 seconds" do
    assert(
     Cerbas.Dispatcher.dispatch({"halt", %{"delay" => 5000}, "tom", {nil}})
     ==
     ""
    )
  end

end
