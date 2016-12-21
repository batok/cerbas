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
     Cerbas.Dispatcher.dispatch({"hellox", "foo", "bar"})
     ==
     {:error, "Undefined function"}
    )
  end

  test "hello world" do
    assert(
     Cerbas.Dispatcher.dispatch({"hello", %{}, "tom"})
     ==
     "hello world!"
    )
  end

  test "async func" do
    assert(
     Cerbas.Dispatcher.dispatch({"asyncfunc", %{}, "tom"})
     ==
     ""
    )
  end

  test "function with arguments" do
    assert(
     Cerbas.Dispatcher.dispatch({"withargs", %{"foo" => "bar"}, "tom"})
     ==
     "bar"
    )
  end

  test "function with error" do
    assert(
     Cerbas.Dispatcher.dispatch({"witherror", %{}, "tom"})
     ==
     {:error, "unexpected error"}
    )
  end

  test "function from other module 1" do
    assert(
     Cerbas.Dispatcher.dispatch({"sum", %{"a" => 1, "b" => 2}, "tom"})
     ==
     3
    )
  end

  test "function from other module 2" do
    assert(
     Cerbas.Dispatcher.dispatch({"sum", %{"a" => "x", "b" => 2}, "tom"})
     ==
     {:error, "bad arguments"}
    )
  end

  test "function proxiedhostport" do
    assert(
     Cerbas.Dispatcher.dispatch({"proxiedhostport", %{"server" => "tornado"}, "tom"})
     ==
     get_port()
    )
  end

  test "halt in 5 seconds" do
    assert(
     Cerbas.Dispatcher.dispatch({"halt", %{"delay" => 5000}, "tom"})
     ==
     ""
    )
  end

  test "wait " do
    :timer.sleep 6
    assert 1 == 1
  end
end
