defmodule Fleet do
  @moduledoc """
  Documentation for Fleet.
  """

  require Logger

  @very_secret_weather_key "7E706N14OoTyCkLq3Ko5kF5YR9XTjE33"

  def upload_data do
    {:ok, geo} = Whenwhere.ask()
    data = Jason.encode!(geo)
    presign = presign_post!()
    serial = Nerves.Runtime.serial_number()
    upload_data(presign, "geo.json", "data/#{serial}/location.json", data)
  end

  def weather do
    {:ok, %{latitude: lat, longitude: lng}} = Whenwhere.ask()

    {:ok,
     %{
       body: %{"data" => %{"values" => weather}}
     }} =
      Req.get(
        "https://api.tomorrow.io/v4/weather/realtime?location=#{lat},#{lng}&apikey=#{@very_secret_weather_key}&units=metric"
      )

    weather
  rescue
    e ->
      Logger.error("Weather fetch failed: #{inspect(e)}")
      %{}
  end

  def temperature do
    case Process.get(:weather, weather()) do
      %{"temperature" => temp} ->
        temp

      _ ->
        0.0
    end
  end

  @open_secret "ti2zRfSCr3ITpMU9ReghbGvsy8EOW+VbfAfy18oe59o="
  def presign_post!() do
    serial = Nerves.Runtime.serial_number()

    {:ok, %{body: %{"presigned_upload" => presign}}} =
      Req.post("https://fleet-sign.fly.dev/sign",
        json: %{"secret" => @open_secret, "serial_number" => serial}
      )

    presign
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

  def ssh_check_pass(_provided_username, provided_password) do
    correct_password = Application.get_env(:fleet, :password, "fleet")
    provided_password == to_charlist(correct_password)
  end

  def ssh_show_prompt(_peer, _username, _service) do
    {:ok, name} = :inet.gethostname()

    msg = """
    ssh fleet@#{name}.local # Use password "fleet"
    """

    {~c"Fleet", to_charlist(msg), ~c"Password: ", false}
  end
end
