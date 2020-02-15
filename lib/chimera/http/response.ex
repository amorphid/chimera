defmodule Chimera.HTTP.Response do
  defstruct body: nil,
            content_length: nil,
            headers: [],
            http_version: nil,
            status_code: nil
end
