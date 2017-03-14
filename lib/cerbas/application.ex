defmodule Cerbas.Application do
  @moduledoc false
  @proxy_enabled Application.get_env(:cerbas, :proxy_enabled)
  import Cerbas, only: [color_info: 2]

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    cronfile = "CRONTAB"
    pool_redis_opts = [
      name: {:local, :redix_poolboy},
      worker_module: Redix,
      size: 4,
      max_overflow: 2
    ]
    {redis_host, redis_port, redis_db} = Cerbas.get_redis_conf()
    redis_connection_params = [ 
      host: redis_host,
      port: redis_port,
      database: redis_db 
    ]

    w = [
      :poolboy.child_spec(:redix_poolboy,
        pool_redis_opts, redis_connection_params),
      worker(Task, [Cerbas.Cron, :crondispatcher, [cronfile]], id: :cronserver)
    ]

    children =
    if @proxy_enabled do
      "web server added to supervised items" |> color_info(:green)
      w ++ [worker(Cerbas.Web, [], id: :proxyserver), worker(Cerbas, [], id: :apiserver)]
    else
      "web server NOT added to supervised items" |> color_info(:green)
      w ++ [worker(Cerbas, [], id: :apiserver)]
    end
    "supervised items #{length children}" |> color_info(:yellow)

    opts = [strategy: :one_for_one, name: Cerbas.Supervisor]
    Supervisor.start_link(children, opts)
    {:ok, self()}
  end
end
