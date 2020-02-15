defmodule Chimera.Metabolizers.Root do
  alias Chimera.HTTP.Date

  @clrf "\r\n"

  def get(_) do
    [
      "HTTP/1.1 200 OK",
      "Date: #{Date.utc_formatted_string_now()}",
      "Content-Length: 11",
      "Server: ECS (mic/9A89)"
    ]
    |> Enum.join(@clrf)
    |> Kernel.<>(@clrf)
    |> Kernel.<>(@clrf)
    |> Kernel.<>("hello world")
  end
end
