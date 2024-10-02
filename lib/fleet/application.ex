defmodule Fleet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fleet.Supervisor]
    setup_wifi()

    children =
      [
        # Children for all targets
        # Starts a worker by calling: Fleet.Worker.start_link(arg)
        # {Fleet.Worker, arg},
      ] ++ children(target(), Fleet.role())

    dbg(children)

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host, :databaser) do
    [{Fleet.Databaser, path: "/tmp/podcast-index.sqlite"}]
  end

  def children(:host, :parser) do
    [Fleet.Parser]
  end

  def children(_target, :transcripter) do
    [Fleet.Transcriber]
  end

  def children(_target, :databaser) do
    [Fleet.Databaser]
  end

  def children(_target, :parser) do
    [Fleet.Parser]
  end

  if Mix.target() == :host do
    defp setup_wifi(), do: :ok
  else
    defp setup_wifi() do
      kv = Nerves.Runtime.KV.get_all()

      if true?(kv["wifi_force"]) or not wlan0_configured?() do
        ssid = kv["wifi_ssid"]
        passphrase = kv["wifi_passphrase"]

        unless empty?(ssid) do
          _ = VintageNetWiFi.quick_configure(ssid, passphrase)
          :ok
        end
      end
    end

    defp wlan0_configured?() do
      VintageNet.get_configuration("wlan0") |> VintageNetWiFi.network_configured?()
    catch
      _, _ -> false
    end

    defp true?(""), do: false
    defp true?(nil), do: false
    defp true?("false"), do: false
    defp true?("FALSE"), do: false
    defp true?(_), do: true

    defp empty?(""), do: true
    defp empty?(nil), do: true
    defp empty?(_), do: false
  end

  def target() do
    Application.get_env(:berlin2024, :target)
  end
end
