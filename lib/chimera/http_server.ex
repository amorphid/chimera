defmodule Chimera.HTTPServer do
  @moduledoc false

  alias Chimera.HTTPServer.ResponderSupervisor

  use GenServer

  defmodule Data do
    defstruct listen_socket: nil,
              accept_timeout: nil,
              portno: nil,
              protocol_module: nil,
              protocol_opts: nil
  end

  #######
  # API #
  #######

  def start_link(init_opts, start_opts) do
    GenServer.start_link(
      __MODULE__,
      init_opts(init_opts),
      start_opts(start_opts)
    )
  end

  #############
  # Callbacks #
  #############

  def handle_continue(
        :open_socket,
        %Data{
          portno: portno,
          protocol_module: protocol_module,
          protocol_opts: protocol_opts
        } = data
      ) do
    {:ok, listen_socket} = protocol_module.listen(portno, protocol_opts)
    _ = send(self(), :accept)
    {:noreply, struct!(data, listen_socket: listen_socket)}
  end

  def handle_info(
        :accept,
        %Data{
          accept_timeout: accept_timeout,
          listen_socket: listen_socket,
          protocol_module: protocol_module
        } = data
      ) do
    opts = {protocol_module, listen_socket, accept_timeout}

    :ok =
      case ResponderSupervisor.start_child(opts) do
        {:ok, _} ->
          :ok

        {:error, _} ->
          :ok

        :ignore ->
          :ok
      end

    _ = send(self(), :accept)
    {:noreply, data}
  end

  def init(opts) do
    {:ok, struct!(%Data{}, opts), {:continue, :open_socket}}
  end

  ###########
  # Private #
  ###########

  defp default_start_opts() do
    [
      name: __MODULE__
    ]
  end

  defp default_init_opts(:non_protocol_opts) do
    %{
      accept_timeout: 5_000,
      listen_socket: nil,
      portno: 4_000,
      protocol_module: :ssl
    }
  end

  defp default_init_opts(:protocol_opts) do
    [
      :binary,
      active: false,
      certfile: "cert.pem",
      keyfile: "key.pem",
      reuseaddr: true
    ]
  end

  defp init_opts(opts) do
    protocol_opts =
      protocol_opts(
        default_init_opts(:protocol_opts),
        Map.get(opts, :protocol_opts, [])
      )

    non_protocol_opts =
      Map.merge(
        default_init_opts(:non_protocol_opts),
        Map.delete(opts, :protocol_opts)
      )

    Map.put(non_protocol_opts, :protocol_opts, protocol_opts)
  end

  defp protocol_opts(default_opts, opts) do
    {default_unary_opts, default_binary_opts} =
      default_opts
      |> Enum.reduce({[], []}, fn
        opt, {unary_opts, binary_opts} when is_atom(opt) ->
          {[opt | unary_opts], binary_opts}

        {_, _} = opt, {unary_opts, binary_opts} ->
          {unary_opts, [opt | binary_opts]}
      end)

    {unary_opts, binary_opts} =
      opts
      |> Enum.reduce({[], []}, fn
        opt, {unary_opts, binary_opts} when is_atom(opts) ->
          {[opt | unary_opts], binary_opts}

        {_, _} = opt, {unary_opts, binary_opts} ->
          {unary_opts, [opt | binary_opts]}
      end)

    unary_opts2 =
      default_unary_opts
      |> Kernel.++(unary_opts)
      |> Enum.uniq()

    binary_opts2 = Keyword.merge(default_binary_opts, binary_opts)
    unary_opts2 ++ binary_opts2
  end

  defp start_opts(opts) do
    Keyword.merge(default_start_opts(), opts)
  end
end
