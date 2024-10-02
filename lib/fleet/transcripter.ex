defmodule Fleet.Transcripter do
  use GenServer

  require Logger

  alias Exqlite.Basic, as: DB

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @start_offset "Wed, 01 Oct 2024 13:17:52 GMT"
  def init(opts) do
    Logger.info("Starting transcripter worker...")

    offset =
      @start_offset
      |> Timex.parse!("{RFC1123}")
      |> Timex.format!("{RFC3339}")

    {:ok,
     %{
       serving: nil,
       offset: offset,
       scratch_file: Keyword.get(opts, :scratch_file, "/data/scratch.mp3")
     }, {:continue, :setup}}
  end

  def handle_continue(:setup, state) do
    Nx.default_backend(EXLA.Backend)
    {:ok, whisper} = Bumblebee.load_model({:hf, "openai/whisper-small"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "openai/whisper-small"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/whisper-small"})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "openai/whisper-small"})

    serving =
      Bumblebee.Audio.speech_to_text_whisper(whisper, featurizer, tokenizer, generation_config,
        defn_options: [compiler: EXLA],
        stream: true,
        timestamps: :segments
      )

    send(self(), :run)

    {:noreply, %{state | serving: serving}}
  end

  def handle_info(:run, state) do
    Logger.info("Fetching episodes from #{state.offset}")
    {entry, dirname, offset} = get_next_parsed!(state.offset)

    # Deal with entry
    if entry do
      %{"id" => id, "title" => title, "enclosure" => %{"url" => url}} = entry

      Logger.info("Attempting download: #{url}")

      case Req.get(url, into: File.stream!(state.scratch_file)) do
        {:ok, %{status: status}} when status < 400 ->
          Logger.info("Downloaded")

          transcript =
            Nx.Serving.run(state.serving, {:file, state.scratch_file})
            |> Enum.map(fn chunk ->
              Logger.info("Transcript: #{inspect(chunk)}")
              chunk
            end)

          key = Path.join(dirname, "transcript.json")
          Logger.info("Transcript saved: #{key}")
          Fleet.put_data(key, Jason.encode!(transcript))

        {:ok, %{status: status}} ->
          Logger.error("Failed to get episode ID #{id} (#{title}), status: #{inspect(status)}")

        {:error, err} ->
          Logger.error("Failed to get episode ID #{id} (#{title}), error: #{inspect(err)}")
      end
    end

    send(self(), :run)

    {:noreply, %{state | offset: offset}}
  end

  defp get_next_parsed!(offset) do
    Fleet.list_keys_from_oldest!("podcasts", offset)
    |> tap(fn keys ->
      Logger.info("Got #{Enum.count(keys)} keys for #{offset}")
    end)
    |> check_for_new(offset)
  end

  defp check_for_new([], offset) do
    Logger.info("Exhausted keys, wrapping up for another go-around. New offset: #{offset}")

    # Should have moved the offset forward at least
    {nil, nil, offset}
  end

  defp check_for_new([key | keys], offset) do
    Logger.info("Key: #{key}")

    if String.ends_with?(key, "/entry.json") do
      dirname = Path.dirname(key)
      neighbors = Fleet.list_keys!(dirname <> "/")
      marker = Path.join(dirname, "transcripter-started.txt")
      {:ok, %{headers: headers, body: body}} = Fleet.get_data(key)

      last_modified =
        Timex.parse!(hd(headers["last-modified"]), "{RFC1123}") |> Timex.format!("{RFC3339}")

      if marker not in neighbors do
        Logger.info("No start marker for: #{key}")
        # Mark it as started
        Fleet.put_data(marker, Nerves.Runtime.serial_number())
        Logger.info("Claimed #{key} with #{marker}")
        {Jason.decode!(body), dirname, last_modified}
      else
        Logger.info("Skipping as marker exists for: #{key}")
        check_for_new(keys, last_modified)
      end
    else
      Logger.debug("Not a entry.json, skipping.")
      check_for_new(keys, offset)
    end
  end
end
