defmodule Chimera.HTTPServer.ResponderSupervisor do
  alias Chimera.HTTPServer.Responder

  #######
  # API #
  #######

  def start_child(args) do
    spec = %{
      id: Responder,
      start: {Responder, :start_link, [args]},
      type: :worker,
      restart: :temporary,
      shutdown: 500
    }

    Supervisor.start_child(__MODULE__, spec)
  end

  def start_link(_) do
    children = []
    opts = [name: __MODULE__, restart: :temporary, strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  #############
  # Callbacks #
  #############

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
