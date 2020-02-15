defmodule Chimera.HTTPClient do
  use GenServer

  alias Chimera.HTTPClient.RequesterSupervisor

  @default_receive_timeout 5_000

  defmodule Data do
    defstruct []
  end

  #######
  # API #
  #######

  def get(unparsed_uri, opts \\ [], receive_timeout \\ @default_receive_timeout)
      when is_list(opts) and
             (is_integer(receive_timeout) or receive_timeout == :infinity) do
    ref = make_ref()
    from = {self(), ref}
    method = "GET"

    :ok =
      GenServer.cast(
        __MODULE__,
        {:download, {from, method, unparsed_uri, opts, receive_timeout}}
      )

    receive do
      {response, ^ref} ->
        response
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, :noop, name: __MODULE__)
  end

  #############
  # Callbacks #
  #############

  def handle_cast({:download, args}, %Data{} = data) do
    {:ok, _} = RequesterSupervisor.start_child(args)

    {:noreply, data}
  end

  def init(_) do
    {:ok, %Data{}}
  end
end
