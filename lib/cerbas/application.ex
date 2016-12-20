defmodule Cerbas.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

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
    children = [
      :poolboy.child_spec(:redix_poolboy,
        pool_redis_opts, redis_connection_params),
       worker(Task, [Cerbas.Cron, :crondispatcher, [cronfile]], id: :cronserver),
       worker(Cerbas.Web, [])

      #worker(Cerbas.Cron, "CRONTAB")
      # Starts a worker by calling: Cerbas.Worker.start_link(arg1, arg2, arg3)
      # worker(Cerbas.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cerbas.Supervisor]
    Supervisor.start_link(children, opts)
    Cerbas.init
  end
end
