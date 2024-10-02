defmodule Fleet.Parser do
  use GenServer

  require Logger

  alias Exqlite.Basic, as: DB

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %{ready?: false}
    Logger.info("Starting parser worker...")
    {:ok, state, {:continue, :run}}
  end

  def handle_continue(:run, state) do

    {:noreply, state}
    #{:noreply, state, {:continue, :run}}
  end
end
