defmodule Fleet do
  @moduledoc """
  Documentation for Fleet.
  """

  def upload_data do
    location = %{foo: "bla"}

    data = Jason.encode!(location)
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

  def upload_data(presigned_url, name, key, data) do
    multipart =
      Multipart.new()
      |> Multipart.add_part(Multipart.Part.text_field(key, "key"))
      |> Multipart.add_part(Multipart.Part.text_field("nerves-fleet-data", "bucket"))
      |> Multipart.add_part(Multipart.Part.file_content_field(name, data, :file, filename: name))

    content_length = Multipart.content_length(multipart)
    content_type = Multipart.content_type(multipart, "multipart/form-data")

    headers = [
      {"Content-Type", content_type},
      {"Content-Length", to_string(content_length)}
    ]

    dbg(headers)

    Req.post(
      presigned_url,
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
    ssh fleet@#{name}.local # Use password "kiosk"
    """

    {~c"Fleet", to_charlist(msg), ~c"Password: ", false}
  end
end
