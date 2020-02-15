defmodule Mix.Tasks.Chimera.Test.GenerateCerts do
  @moduledoc "Generate SSL certs for testing"
  use Mix.Task

  @shortdoc @moduledoc
  def run(_) do
    # Refer to https://letsencrypt.org/docs/certificates-for-localhost/
    System.cmd("bash", [
      "-c",
      "openssl req -x509 -out cert.pem -keyout key.pem -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' -extensions EXT -config <( printf '[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth')"
    ])
  end
end
