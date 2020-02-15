defmodule Chimera.Application do
  @moduledoc false

  use Application

  alias Chimera.HTTPClient
  alias Chimera.HTTPClient.RequesterSupervisor
  alias Chimera.HTTPServer.ResponderSupervisor

  def start(_type, args) do
    _ =
      Enum.each(args, fn {app, configs} ->
        _ =
          Enum.each(configs, fn {key, value} ->
            Application.put_env(app, key, value)

            if app == :logger do
              Logger.configure([{key, value}])
            end
          end)
      end)

    children = [
      HTTPClient,
      RequesterSupervisor,
      ResponderSupervisor
    ]

    opts = [strategy: :one_for_one, name: Chimera.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
