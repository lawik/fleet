defmodule Fleet do
  @moduledoc """
  Documentation for Fleet.
  """

  def upload_data do
    {:ok, geo} = Whenwhere.ask()
    data = Jason.encode!(geo)
    dbg(data)
    presign = presign_post!()
    dbg(presign)
    serial = Nerves.Runtime.serial_number()
    upload_data(presign, "geo.json", "data/#{serial}/location.json", data)
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
      #|> Multipart.add_part(Multipart.Part.text_field("nerves-fleet-data", "bucket"))
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
    dbg(headers)

    Req.post(
      url,
      headers: headers,
      body: Multipart.body_stream(multipart)
    )
  end
end
