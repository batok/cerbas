defmodule Cerbas.Web do
  @moduledoc false
  import Cerbas
  alias Cerbas.Dispatcher
  import ShortMaps
  use Plug.Router
  import Plug.Conn
  plug Plug.Logger
  plug :match
  plug :dispatch

  @proxy_target_flask Application.get_env(:cerbas, :proxy_target_flask)
  @proxy_target_pyramid Application.get_env(:cerbas, :proxy_target_pyramid)
  @proxy_target_ror Application.get_env(:cerbas, :proxy_target_ror)
  @proxy_target_express Application.get_env(:cerbas, :proxy_target_express)
  @proxy_target_django Application.get_env(:cerbas, :proxy_target_django)
  @proxy_target_tornado Application.get_env(:cerbas, :proxy_target_tornado)
  @proxy_port Application.get_env(:cerbas, :proxy_port)

  defmacro r_json(j) do
    quote do
      encoded = 
      case Poison.encode(unquote(j)) do
        {:ok, value} -> value
        val -> 
          "#{inspect val}" |> color_info(:yellow)
          "Problem encoding json" |> color_info(:lightred)
          %{} |> Poison.encode!
      end
      status = 200
      conn
      |> var!()
      |> put_resp_content_type("application/json")
      |> send_resp(status, encoded)
    end
  end

  def error(conn, error, error_number \\ 403) do
    send_resp(conn, error_number, error) 
  end

  def list_to_map(list, fields) 
    when is_list(list)
    when is_list(fields) 
    when length(list) == length(fields) do
    fields |> Enum.zip(list) |> Enum.into(%{})
  end 

  def list_to_map(list, fields), do: %{}

  def req_body_map(conn) do
    case Plug.Conn.read_body(conn, length: 1_000_000) do
      {:ok, value, c} -> 
        if value == "" do
          %{}
        else 
          case Poison.decode(value) do
            {:ok, val} -> val
            _ -> %{}
          end
        end
      _ -> %{}
    end
  end

  def qp(conn) do
    cn = Plug.Conn.fetch_query_params(conn)
    cn.params
  end

  def apicall(~m(func args source), conn), do:
    apicall(func, args, source, conn)

  def apicall(~m(func args source)s, conn), do:
    apicall(func, args, source, conn)

  def apicall(func, args, source, conn) do
    response = 
    case Dispatcher.dispatch({func, args, source}) do
      {:error, msg} -> %{status: "error", data: msg}
      val -> %{status: "ok", data: val}
      _ -> %{status: "error", data: ""}
    end 
    r_json response
    rescue
      e -> 
        "rescue zone" |> color_info(:red)
        r_json %{status: "error", data: "rescued"}
  end

  def start_link() do
    :fuse.install(:fuse_server_timeout, {{:standard, 2, 3_000},{:reset, 10_000}})
    :fuse.install(:fuse_server_not_available, {{:standard, 2, 3_000},{:reset, 10_000}})
    "Web server and proxy started" |> color_info(:blue)
    Plug.Adapters.Cowboy.http(__MODULE__, [], port: @proxy_port)
  end

  def local_foo(conn) do
    ~m(var1 var2) = qp(conn)
    r_json ~m(var1 var2) 
    rescue
      e -> 
        "#{inspect e}" |> color_info(:red)
        error(conn, "must use var1 and var2")
  end

  def general_api_handler(conn) do
    ~m(request) = req_body_map(conn)
    ~m(func args source) = request
    apicall(func, args, source, conn)
    rescue
      e -> 
        "#{inspect e}" |> color_info(:red)
        error(conn, "you have to provide a json body with request, etc")
  end

  get "/" do
    "OK /" |> color_info(:lightblue)
    conn 
    |> send_resp(200, "OK")
  end

  get "/api/hello" do
    "{\"func\": \"hello\", \"args\": {}, \"source\": \"web\"}" 
    |> get_request_parts |> Dispatcher.dispatch()
    conn 
    |> send_resp(200, "HELLO")
  end

  get "/api/hello2" do
    foo = "hello2"
    func = "withargs"
    args = ~m(foo)
    source = "web"
    apicall(~m(func args source), conn)
  end

  match _ do
    rp = conn.request_path
    route_match = 
    case conn.method do
      "GET" ->
        case rp do
          "/api/foo" -> {__MODULE__, :"local_foo"}
          "/api/general" -> {__MODULE__, :"general_api_handler"}
          "/api2/foo" <> _ -> :pyramid
          "/api3/foo" -> :ror
          "/api4/foo" -> :django
          "/api5/foo" -> :flask
          "/api6/foo" -> :express
          "/api7/foo" -> :tornado
          _ -> nil
        end
        _ -> nil
    end
    if is_nil(route_match) do
      "NOT FOUND" |> color_info(:red)
      conn
      |> send_resp(404, "NOT FOUND")
    else
      if is_atom(route_match) do
        proxy(conn, route_match)
      else
        {module, func} = route_match
        apply(module, func, [conn])
      end
    end
  end

  defp proxy(conn, server_atom) do
    "Proxying ... #{conn.request_path} to #{inspect server_atom}" |> color_info(:yellow)
    case :fuse.ask(:fuse_server_timeout, :sync) do
      :blown -> error(conn, "Server Timeout", 500)
      _ -> case :fuse.ask(:fuse_server_not_available, :sync) do
        :blown -> error(conn, "Server Not Available", 500)
        :ok ->  
          method = conn.method |> String.downcase |> String.to_existing_atom
          case :hackney.request(method, uri(conn, server_atom), conn.req_headers, :stream, []) do
            {:ok, client} -> 
              conn
              |> write_proxy(client)
              |> read_proxy(client)
            {:error, :connect_error} -> 
              "Server Timeout" 
              |> color_info(:lightred) 
              :fuse.melt(:fuse_server_timeout)
              error(conn, "Server Timeout", 500)
            {:error, _} -> 
              "Server not available" 
              |> color_info(:lightred) 
              :fuse.melt(:fuse_server_not_available)
              error(conn, "Server Not Available", 500)
           end
        end
    end
  end

  defp write_proxy(conn, client) do
    case read_body(conn, []) do
      {:ok, body, conn} ->
        :hackney.send_body(client, body)
        conn
      {:more, body, conn} ->
        :hackney.send_body(client, body)
        write_proxy(conn, client)
    end
  end

  defp log_read_proxy(conn, status, body) do
    "Response from real webserver" |> color_info(:green)
    "#{inspect conn}" |> color_info(:green)
    conn
  end

  defp header_conversions(headers, backend \\ :pyramid) do
    case backend do
      val when val in [:pyramid, :flask, :tornado, :express] -> 
        headers = List.keydelete(headers, "Server", 0)
        headers = List.keydelete(headers, "Content-Length", 0)
        headers ++ 
        [{"cache-control", "max-age=0, private, must-revalidate"}]
      _ -> headers
    end
  end

  defp read_proxy(conn, client) do
    {:ok, status, headers, client} = :hackney.start_response(client)
    {:ok, body} = :hackney.body(client)
    headers = List.keydelete(headers, "Transfer-Encoding", 0)
    headers = header_conversions(headers)
    %{conn | resp_headers: headers}
    |> send_resp(status, body)
  end

  defp uri(conn, server_atom) do
    proxy_target = proxy_host(server_atom)
    base = proxy_target <> "/" <> Enum.join(conn.path_info, "/")
    case conn.query_string do
      "" -> base
      qs -> base <> "?" <> qs
    end
  end

  def proxy_host(server_atom) do
    server =
    case server_atom do
      :pyramid -> @proxy_target_pyramid 
      :ror -> @proxy_target_ror 
      :flask -> @proxy_target_flask
      :django -> @proxy_target_django
      :express -> @proxy_target_express
      :tornado -> @proxy_target_tornado
      _ -> nil
    end 
    server |> color_info(:yellow)
  end

end
