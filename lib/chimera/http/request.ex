defmodule Chimera.HTTP.Request do
  defstruct content_length: nil,
            headers: [],
            http_version: nil,
            protocol_module: nil,
            method: nil,
            uri: nil
end
