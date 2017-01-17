# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :cerbas, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:cerbas, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
     config :logger, :console, format: "\ncerbas $time $metadata[$level] $levelpad$message"
     config :cerbas, proxy_enabled: true
     config :cerbas, only_raw_response: false # if true msgpack is not handled also
     config :cerbas, proxy_target_flask: "http://127.0.0.1:5000"
     config :cerbas, proxy_target_pyramid: "http://127.0.0.1:6543"
     config :cerbas, proxy_target_tornado: "http://127.0.0.1:8888"
     config :cerbas, proxy_target_express: "http://127.0.0.1:3000"
     config :cerbas, proxy_target_sinatra: "http://localhost:9494"
     config :cerbas, proxy_port: 4455
     config :cerbas, delay_in_every_loop: 200
     config :cerbas, api_timeout: 5000
     config :cerbas, api_valid_sources: ["cerbastest", "foo", "bar", "web", "tom"]
     config :cerbas, api_valid_users: ["tom", "foo"]
#     
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
     import_config "#{Mix.env}.exs"
