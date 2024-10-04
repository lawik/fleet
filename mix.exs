defmodule Fleet.MixProject do
  use Mix.Project

  # @app :fleet
  @app :berlin2024
  @version "0.2.0-rc6"
  @all_targets [
    :rpi,
    :rpi0,
    :rpi2,
    :rpi3,
    :rpi3a,
    :rpi4,
    :rpi5,
    :bbb,
    :osd32mp1,
    :x86_64,
    :grisp2,
    :mangopi_mq_pro,
    :srhub
  ]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.11",
      archives: [nerves_bootstrap: "~> 1.12"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Fleet.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.10.0"},
      {:toolshed, "~> 0.4"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.0"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.0", targets: @all_targets},

      # Dependencies for specific targets
      # NOTE: It's generally low risk and recommended to follow minor version
      # bumps to Nerves systems. Since these include Linux kernel and Erlang
      # version updates, please review their release notes in case
      # changes to your application are needed.
      {:nerves_system_rpi, "~> 1.24", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.24", runtime: false, targets: :rpi0},
      {:nerves_system_rpi2, "~> 1.24", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 1.24", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.24", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.24", runtime: false, targets: :rpi4},
      # {
      #   :nerves_system_rpi4,
      #   # nerves: [compile: true],
      #   path: "../../projects/nerves_systems/src/nerves_system_rpi4",
      #   runtime: false,
      #   targets: :rpi4
      # },
      {:nerves_system_rpi5, "~> 0.3.0", runtime: false, targets: :rpi5},
      {:nerves_system_bbb, "~> 2.19", runtime: false, targets: :bbb},
      {:nerves_system_osd32mp1, "~> 0.15", runtime: false, targets: :osd32mp1},
      {:nerves_system_x86_64, "~> 1.24", runtime: false, targets: :x86_64},
      {:nerves_system_grisp2, "~> 0.8", runtime: false, targets: :grisp2},
      {:nerves_system_mangopi_mq_pro, "~> 0.6", runtime: false, targets: :mangopi_mq_pro},
      {:nerves_system_srhub, "~> 0.33", runtime: false, targets: :srhub},
      # {:nerves_hub_link, "~> 2.5"},
      {:nerves_hub_link,
       github: "lawik/nerves_hub_link", branch: "extension-pubsub", override: true},
      {:nerves_hub_link_geo, github: "nervescloud/nerves_hub_link_geo"},
      {:nerves_hub_health, github: "nervescloud/nerves_hub_health"},
      {:nerves_hub_cli, "~> 2.0"},
      {:req, "~> 0.5.6"},
      {:multipart, "~> 0.4.0"},
      # {:membrane_core, "~> 1.1"},
      # {:membrane_file_plugin, "~> 0.17.2"},
      # {:membrane_mp3_mad_plugin, "~> 0.18.3"},
      # {:membrane_ffmpeg_swresample_plugin, "~> 0.20.2"},
      # {:bumblebee, "~> 0.5"},
      # for axon
      {:table_rex, "~> 4.0", override: true},
      {:axon, github: "elixir-nx/axon", override: true, targets: [:rpi4, :rpi5, :host]},
      {:bumblebee, github: "elixir-nx/bumblebee", override: true, targets: [:rpi4, :rpi5, :host]},
      {:nx, "~> 0.7", targets: [:rpi4, :rpi5, :host]},
      {:exla, "~> 0.7", targets: [:rpi4, :rpi5, :host]},
      {:exqlite, "~> 0.24.2"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.7"},
      {:feeder_ex, "~> 1.1"},
      {:feeder, "~> 2.3", manager: :rebar3, override: true},
      {:timex, "~> 3.7"}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end
end
