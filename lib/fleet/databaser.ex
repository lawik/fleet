defmodule Fleet.Databaser do
  use GenServer

  require Logger

  alias Exqlite.Basic, as: DB

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @path "/data/podcast-index.sqlite"
  @url "https://fly.storage.tigris.dev/underjord-streaming-public/podcast-index.db"
  def init(opts) do
    state = %{ready?: false, conn: nil, path: Keyword.get(opts, :path, @path)}
    Logger.info("Starting database worker...")
    send(self(), :setup)
    {:ok, state}
  end

  def handle_info(:setup, state) do
    state =
      case File.stat(state.path) do
        {:ok, %{size: size}} when size > 0 ->
          Logger.info("Database already exists at: #{state.path}")
          {:ok, conn} = DB.open(state.path)
          %{state | ready?: true, conn: conn}

        {:ok, %{size: 0}} ->
          Logger.info("Found empty file. Starting download over from: #{@url}")
          Req.get!(@url, into: File.stream!(state.path))
          Logger.info("Downloaded successfully to: #{state.path}")
          {:ok, conn} = DB.open(state.path)
          %{state | ready?: true, conn: conn}

        {:error, :enoent} ->
          Logger.info("Starting download from: #{@url}")
          Req.get!(@url, into: File.stream!(state.path))
          Logger.info("Downloaded successfully to: #{state.path}")
          {:ok, conn} = DB.open(state.path)
          %{state | ready?: true, conn: conn}

        err ->
          Logger.error(
            "Unexpected error stat:ing the podcast index db file on disk: #{inspect(err)}"
          )

          %{state | ready?: false}
      end

    send(self(), :run)
    {:noreply, state}
  rescue
    _ ->
      Process.send_after(self(), :setup, 5000)
      {:noreply, state}
  end

  @limit 100
  def handle_info(:run, state) do
    try do
      latest_id = fetch_latest()
      Logger.info("Getting podcasts starting at ID: #{latest_id}")

      podcasts =
        state.conn
        |> get_podcasts(latest_id, @limit)

      Logger.info("Got #{Enum.count(podcasts)} podcasts.")

      if podcasts != %{} do
        %{"id" => max_id} = Enum.max_by(podcasts, &Map.get(&1, "id", 0))

        podcasts
        |> Enum.each(fn pod ->
          Logger.info("Saving podcast metadata for ID #{pod["id"]} (#{pod["title"]}).")

          try do
            {:ok, _} = put_podcast(pod)
          rescue
            err ->
              Logger.warning("Failed to save podcast: #{inspect(err)}")
          end
        end)

        # weak control, is fine
        latest_id = fetch_latest()

        if max_id > latest_id do
          Logger.info("Setting new latest fetch id: #{max_id}")
          put_latest(max_id)
        end
      else
        Logger.info("Chilling for 30 seconds, seem to be out of podcasts")
        :timer.sleep(30_000)
      end

      send(self(), :run)
      {:noreply, state}
    rescue
      _ ->
        Process.send_after(self(), :run, 5000)
        {:noreply, state}
    end
  end

  defp fetch_latest do
    case Fleet.get_data("databaser/latest_id.txt") do
      {:ok, %{status: 200, body: body}} ->
        String.to_integer(body)

      {:ok, %{status: 404}} ->
        0
    end
  end

  defp put_latest(id) do
    Fleet.put_data("databaser/latest_id.txt", to_string(id))
  end

  defp put_podcast(pod) do
    Fleet.put_data("podcasts/#{pod["id"]}/meta.json", Jason.encode!(pod))
  end

  # defp get_english_tech_podcasts(conn, latest_id, limit) do
  #   query = """
  #     select
  #       id,
  #       url,
  #       title,
  #       language collate nocase as cat
  #     from
  #       podcasts
  #     where
  #       id > ?
  #       and
  #       dead = 0
  #       and
  #       substr(cat,1,2) = 'en'
  #       and
  #       category1 = 'technology'
  #     order by id asc
  #     limit ?
  #   """

  #   {:ok, rows, keys} =
  #     conn
  #     |> DB.exec(query, [latest_id, limit])
  #     |> DB.rows()

  #   Enum.map(rows, fn row ->
  #     Enum.zip(keys, row)
  #     |> Map.new()
  #   end)
  # end

  defp get_podcasts(conn, latest_id, limit) do
    query = """
      select
        id,
        url,
        title,
        language collate nocase as cat
      from
        podcasts
      where
        id > ?
        and
        dead = 0
        and
        substr(cat,1,2) = 'en'
      order by id asc
      limit ?
    """

    {:ok, rows, keys} =
      conn
      |> DB.exec(query, [latest_id, limit])
      |> DB.rows()

    Enum.map(rows, fn row ->
      Enum.zip(keys, row)
      |> Map.new()
    end)
  end
end
