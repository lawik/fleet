defmodule Fleet.Parser do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @start_offset "Wed, 01 Oct 2024 13:17:52 GMT"
  def init(_opts) do
    Logger.info("Starting parser worker...")

    offset =
      @start_offset
      |> Timex.parse!("{RFC1123}")
      |> Timex.format!("{RFC3339}")

    send(self(), :run)
    {:ok, %{offset: offset}}
  end

  def handle_info(:run, state) do
    try do
      Logger.info("Fetching feeds from #{state.offset}")
      {feed, offset} = get_next_meta!(state.offset)

      # Deal with feed
      if feed do
        %{"id" => id, "url" => url, "title" => title} = feed

        case Req.get(url) do
          {:ok, %{status: status, body: body}} when status < 400 ->
            Logger.info("Fetched RSS feed with status: #{status}")

            case FeederEx.parse(body) do
              {:ok, feed, _} ->
                Logger.info("Parsed RSS feed OK. Entries: #{Enum.count(feed.entries)}")

                feed.entries
                |> Enum.sort_by(
                  fn entry ->
                    Timex.parse!(entry.updated, "{RFC1123}")
                  end,
                  {:asc, DateTime}
                )
                |> Enum.map(fn entry ->
                  hash_id = Fleet.episode_id_hash(entry.id)
                  Logger.info("Episode ID #{entry.id} hashed to #{hash_id}")

                  if entry.enclosure do
                    enclosure = Map.from_struct(entry.enclosure)

                    data =
                      entry
                      |> Map.from_struct()
                      |> Map.put(:enclosure, enclosure)
                      |> Jason.encode!()

                    Fleet.put_data("podcasts/#{id}/episodes/#{hash_id}/entry.json", data)
                  else
                    Logger.info("No enclosure, skipping episode: #{hash_id}")
                  end
                end)

                Fleet.put_data("podcasts/#{id}/parser-done.txt", Nerves.Runtime.serial_number())

              other ->
                Logger.info(
                  "Feed parsing failed. Could be any reason, we just skip: #{inspect(other)}"
                )
            end

          {:ok, %{status: status}} ->
            Logger.error(
              "Failed to get RSS feed for ID #{id} (#{title}), status: #{inspect(status)}"
            )

          {:error, err} ->
            Logger.error("Failed to get RSS feed for ID #{id} (#{title}), error: #{inspect(err)}")
        end
      end

      send(self(), :run)

      {:noreply, %{state | offset: offset}}
    rescue
      _ ->
        Process.send_after(self(), :run, 5000)
        {:noreply, state}
    end
  end

  defp get_next_meta!(offset) do
    Fleet.list_keys_from_oldest!("podcasts", offset)
    |> tap(fn keys ->
      Logger.info("Got #{Enum.count(keys)} keys.")
    end)
    |> check_for_new_feed(offset)
  end

  defp check_for_new_feed([], offset) do
    Logger.info("Exhausted keys, wrapping up for another go-around. New offset: #{offset}")

    # Should have moved the offset forward at least
    {nil, offset}
  end

  defp check_for_new_feed([key | keys], offset) do
    Logger.info("Key: #{key}")

    if String.ends_with?(key, "/meta.json") do
      dirname = Path.dirname(key)
      # Parsing marker can be outside of the current datetime region, get keys for
      # the specific pod
      neighbors = Fleet.list_keys!(dirname <> "/")
      marker = Path.join(dirname, "parser-started.txt")
      {:ok, %{headers: headers, body: body}} = Fleet.get_data(key)

      last_modified =
        Timex.parse!(hd(headers["last-modified"]), "{RFC1123}") |> Timex.format!("{RFC3339}")

      if marker not in neighbors do
        Logger.info("No start marker for: #{key}")
        # Mark it as started
        Fleet.put_data(marker, Nerves.Runtime.serial_number())
        Logger.info("Claimed #{key} with #{marker}")
        {Jason.decode!(body), last_modified}
      else
        Logger.info("Skipping as marker exists for: #{key}")
        check_for_new_feed(keys, last_modified)
      end
    else
      Logger.debug("Not a meta.json, skipping.")
      check_for_new_feed(keys, offset)
    end
  end
end
