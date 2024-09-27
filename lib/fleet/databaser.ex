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
    {:ok, state, {:continue, :setup}}
  end

  def handle_continue(:setup, state) do
    state =
      case File.stat(state.path) do
        {:ok, _} ->
          Logger.info("Database already exists at: #{state.path}")
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

    {:noreply, state, {:continue, :run}}
  end

  def handle_continue(:run, state) do
    latest_id = fetch_latest()

    new_id =
      state.conn
      |> get_english_tech_podcasts(latest_id, limit)

    # TODO: Process podcasts, save information, save latest idea if greater

    latest_id = fetch_latest
    Fleet.put_data("")

    {:noreply, state}
  end

  defp fetch_latest do
    case Fleet.get_data("databaser/latest_id.txt") do
      {:ok, %{status: 200, body: body}} ->
        String.to_integer(body)

      {:ok, %{status: 404}} ->
        0
    end
  end

  defp get_english_tech_podcasts(conn, latest_id, limit) do
    query = """
      select
        url,
        title,
        language collate nocase as cat
      from
        podcasts
      where
        id > ?
        dead = 0
        and
        substr(cat,1,2) = 'en'
        and
        category1 = 'technology'
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
