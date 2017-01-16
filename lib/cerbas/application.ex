defmodule Cerbas.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  @proxy_enabled Application.get_env(:cerbas, :proxy_enabled)

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

    # Define workers and child supervisors to be supervised
    w = [
      :poolboy.child_spec(:redix_poolboy,
        pool_redis_opts, redis_connection_params),
      worker(Cerbas, []),
      worker(Task, [Cerbas.Cron, :crondispatcher, [cronfile]], id: :cronserver),
       #worker(Cerbas.Web, [])
    ]

    children =
    if @proxy_enabled do
      w ++ [ worker(Cerbas.Web, []) ]
    else
      w
    end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cerbas.Supervisor]
    Supervisor.start_link(children, opts)
    #Cerbas.init
    {:ok, self()}
  end
end
