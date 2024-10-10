defmodule Fleet.Validator do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(_) do
    schedule_check()
    {:ok, false}
  end

  def handle_info(:check, _) do
    if NervesHubLink.connected?() do
      Nerves.Runtime.validate_firmware()
      {:noreply, true}
    else
      schedule_check()
      {:noreply, false}
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check, 3000)
  end
end
