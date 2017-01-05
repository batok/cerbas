defmodule Cerbas.Mixfile do
  use Mix.Project

  def project do
    [app: :cerbas,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :poison, :poolboy, :redix, :hackney, :chronos, :fuse],
     mod: {Cerbas.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:poolboy, "~> 1.5"},
      {:poison, "~> 2.0"},
      {:chronos, github: "nurugger07/chronos"},
      {:redix, github: "whatyouhide/redix",
      ref: "f47e6a8ac4fa6c47363ac2a5304b7effdad0ab19"},
      {:exredis , github: "artemeff/exredis", only: [:test]},
      #{:credo, github: "rrrene/credo", only: [:dev, :test]},
      {:credo, "~> 0.5"},
      {:plug, github: "elixir-lang/plug"},
      {:cowboy, "~> 1.0"},
      {:hackney, "~> 1.2.0"},
      {:ex_cron, github: "codestuffers/ex-cron"},
      {:fuse, github: "jlouis/fuse"},
      {:short_maps, github: "whatyouhide/short_maps"}
    ]
  end
end
