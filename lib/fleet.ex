defmodule Fleet do
  @moduledoc """
  Documentation for Fleet.
  """

  require Logger
  import SweetXml

  #  alias ExAws.S3

  def upload_data do
    {:ok, geo} = Whenwhere.ask()
    data = Jason.encode!(geo)
    presign = presign_post!()
    serial = Nerves.Runtime.serial_number()
    upload_data(presign, "geo.json", "data/#{serial}/location.json", data)
  end

  @open_secret "ti2zRfSCr3ITpMU9ReghbGvsy8EOW+VbfAfy18oe59o="
  def claim_resource(key) do
    serial = Nerves.Runtime.serial_number()
    put_data(key, "device-#{serial}")
  end

  def put_data(key, data) do
    presign = presign_post!(key)

    upload_data(presign, "any-filename", key, data)
  end

  def presign_post! do
    serial = Nerves.Runtime.serial_number()

    {:ok, %{body: %{"presigned_upload" => presign}}} =
      Req.post("https://fleet-sign.fly.dev/sign",
        json: %{"secret" => @open_secret, "serial_number" => serial, "method" => "post"}
      )

    presign
  end

  def presign_post!(key) do
    serial = Nerves.Runtime.serial_number()

    {:ok, %{body: %{"presigned_upload" => presign}}} =
      Req.post("https://fleet-sign.fly.dev/sign",
        params: [key: key],
        json: %{"secret" => @open_secret, "serial_number" => serial, "method" => "post"}
      )

    presign
  end

  def presign_get!(key) do
    serial = Nerves.Runtime.serial_number()

    {:ok, %{body: %{"presigned_upload" => presign}}} =
      Req.post("https://fleet-sign.fly.dev/sign",
        params: [key: key],
        json: %{"secret" => @open_secret, "serial_number" => serial, "method" => "get"}
      )

    presign
  end

  defp bucket, do: "nerves-fleet-data"

  def episode_id_hash(episode_id) do
    :crypto.hash(:sha, episode_id)
    |> Base.encode16()
  end

  def get_data(key) do
    Req.get("https://fly.storage.tigris.dev/#{bucket()}/shared/#{key}")
  end

  def list_keys_from_oldest!(prefix, offset) do
    Req.get!("https://fly.storage.tigris.dev/#{bucket()}",
      params: %{
        "list-type" => 2,
        "prefix" => "shared/#{prefix}"
      },
      headers: %{
        "X-Tigris-Query" => "`Last-Modified` > \"#{offset}\" ORDER BY \`Last-Modified\` ASC"
      }
    )
    |> Map.fetch!(:body)
    |> SweetXml.xpath(~x"//ListBucketResult/Contents/Key/text()"l)
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.replace_leading(&1, "shared/", ""))
  end

  def list_keys!(prefix) do
    Req.get!("https://fly.storage.tigris.dev/#{bucket()}",
      params: %{
        "list-type" => 2,
        "prefix" => "shared/#{prefix}"
      }
    )
    |> Map.fetch!(:body)
    |> SweetXml.xpath(~x"//ListBucketResult/Contents/Key/text()"l)
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.replace_leading(&1, "shared/", ""))
  end

  def claimed?(key) do
    case get_data(key) do
      {:ok, %{status: 200}} ->
        true

      {:ok, %{status: 404}} ->
        false
    end
  end

  def upload_data(%{"url" => url, "fields" => fields}, name, _key, data) do
    multipart =
      Multipart.new()
      # |> Multipart.add_part(Multipart.Part.text_field("nerves-fleet-data", "bucket"))
      |> Multipart.add_part(Multipart.Part.file_content_field(name, data, :file, filename: name))

    multipart =
      fields
      |> Enum.reduce(multipart, fn {field, value}, mp ->
        Multipart.add_part(mp, Multipart.Part.text_field(value, field))
      end)

    content_length = Multipart.content_length(multipart)
    content_type = Multipart.content_type(multipart, "multipart/form-data")

    headers = [
      {"Content-Type", content_type},
      {"Content-Length", to_string(content_length)}
    ]

    Req.post(
      url,
      headers: headers,
      body: Multipart.body_stream(multipart)
    )
  end

  def upload_if_missing(%{"url" => url, "fields" => fields}, name, _key, data) do
    multipart =
      Multipart.new()
      # |> Multipart.add_part(Multipart.Part.text_field("nerves-fleet-data", "bucket"))
      |> Multipart.add_part(Multipart.Part.file_content_field(name, data, :file, filename: name))

    multipart =
      fields
      |> Enum.reduce(multipart, fn {field, value}, mp ->
        Multipart.add_part(mp, Multipart.Part.text_field(value, field))
      end)

    content_length = Multipart.content_length(multipart)
    content_type = Multipart.content_type(multipart, "multipart/form-data")

    headers = [
      {"Content-Type", content_type},
      {"Content-Length", to_string(content_length)},
      {"If-Match", "foo"}
    ]

    Req.post(
      url,
      headers: headers,
      body: Multipart.body_stream(multipart)
    )
  end

  def ssh_check_pass(_provided_username, provided_password) do
    correct_password = Application.get_env(:berlin2024, :password, "fleet")
    provided_password == to_charlist(correct_password)
  end

  def ssh_show_prompt(_peer, _username, _service) do
    {:ok, name} = :inet.gethostname()

    msg = """
    ssh fleet@#{name}.local # Use password "fleet"
    """

    {~c"Fleet", to_charlist(msg), ~c"Password: ", false}
  end

  def tasks_executed, do: 0

  # 4.1Gb so let's say 4.5
  @space_for_podcast_index_kb 4.5 * 1024 * 1024
  @target Mix.target()
  def role do
    case @target do
      :host ->
        :transcripter

      :rpi4 ->
        :transcripter

      :rpi5 ->
        :transcripter

      _ ->
        [{_, _total, available_kb, _percent_used}] = :disksup.get_disk_info(~c"/data")

        if available_kb > @space_for_podcast_index_kb do
          :databaser
        else
          :parser
        end
    end
  end

  def swoosh do
    :math.sin(System.system_time(:second))
  end
end
