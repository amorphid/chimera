defmodule Chimera.HTTPServer.Responder do
  use GenServer

  alias Chimera.HTTP
  alias Chimera.HTTP.Request

  @clrf "\r\n"

  defmodule Data do
    defstruct acc: "",
              headers: [],
              protocol_module: nil,
              request: %Request{},
              socket: nil,
              stage: nil
  end

  #######
  # API #
  #######

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  #############
  # Callbacks #
  #############

  def handle_continue(
        :activate,
        %Data{protocol_module: protocol_module, socket: socket} = data
      ) do
    case protocol_module.setopts(socket, active: :once) do
      :ok ->
        {:noreply, data}

      {:error, error} ->
        {:stop, :normal, data}
    end
  end

  def handle_continue(
        :parse,
        %Data{protocol_module: protocol_module, socket: socket, stage: :body} =
          data
      ) do
    case parse_body(data) do
      {:ok, {:complete, %Data{request: request}}} ->
        {metabolizer_module, function} = HTTP.get_route_from_request(request)
        response = apply(metabolizer_module, function, [request])
        _ = protocol_module.send(socket, response)
        :ok = protocol_module.close(socket)
        {:stop, :normal, data}

      {:ok, :incomplete} ->
        {:noreply, data, {:continue, :activate}}
    end
  end

  def handle_continue(:parse, %Data{stage: :headers} = data) do
    case parse_headers(data) do
      {:ok, %Data{} = data2} ->
        {:noreply, struct!(data2, stage: :body), {:continue, :parse}}

      {:ok, :incomplete} ->
        {:noreply, data, {:continue, :activate}}

      {:error, :invalid} ->
        {:stop, :normal, data}
    end
  end

  def handle_continue(:parse, %Data{stage: :request_line} = data) do
    case parse_request_line(data) do
      {:ok, %Data{} = data2} ->
        {:noreply, struct!(data2, stage: :headers), {:continue, :parse}}

      {:ok, :incomplete} ->
        {:noreply, data, {:continue, :activate}}

      {:error, :invalid} ->
        {:stop, :normal, data}
    end
  end

  def handle_continue(
        {:tls_handshake, tls_transposrt_socket},
        %Data{protocol_module: protocol_module} = data
      ) do
    case protocol_module.handshake(tls_transposrt_socket) do
      {:ok, socket} ->
        {:noreply,
         struct!(data,
           protocol_module: protocol_module,
           socket: socket,
           stage: :request_line
         ), {:continue, :activate}}

      {:error, :timeout} ->
        {:stop, :normal, data}
    end
  end

  def handle_info({:ssl, socket, msg}, %Data{acc: acc, socket: socket} = data)
      when is_binary(msg) do
    {:noreply, struct!(data, acc: acc <> msg), {:continue, :parse}}
  end

  def handle_info({:ssl_closed, socket}, %Data{socket: socket} = data) do
    {:stop, :normal, data}
  end

  def init({protocol_module, _, _} = arg) do
    if function_exported?(protocol_module, :transport_accept, 2) do
      init_ssl(arg)
    else
      raise "TODO: add init_tcp(arg)"
    end
  end

  def init_ssl({protocol_module, listen_socket, accept_timeout}) do
    case protocol_module.transport_accept(listen_socket, accept_timeout) do
      {:ok, tls_transposrt_socket} ->
        {:ok, %Data{protocol_module: protocol_module},
         {:continue, {:tls_handshake, tls_transposrt_socket}}}

      {:error, :timeout} ->
        :ignore

      {:error, error} ->
        {:stop, error}
    end
  end

  ###########
  # Private #
  ###########

  defp decode_header(%Data{} = data, "") do
    {:ok, data}
  end

  defp decode_header(%Data{} = data, header_line) do
    case String.split(header_line, ": ") do
      [key, value] ->
        decode_header(data, String.downcase(key), key, value)

      _ ->
        {:error, :invalid}
    end
  end

  defp decode_header(
         %Data{request: %Request{headers: headers} = request} = data,
         "content-length",
         key,
         value
       ) do
    case Integer.parse(value) do
      {content_length, ""} ->
        parse_headers(
          struct!(data,
            request:
              struct!(request,
                content_length: content_length,
                headers: headers ++ [{key, value}]
              )
          )
        )

      _ ->
        {:error, :invalid}
    end
  end

  defp decode_header(
         %Data{request: %Request{headers: headers} = request} = data,
         _,
         key,
         value
       ) do
    parse_headers(
      struct!(data,
        request: struct!(request, headers: headers ++ [{key, value}])
      )
    )
  end

  defp decode_request_line(%Data{request: request} = data, request_line) do
    case String.split(request_line, " ") do
      [method, uri, "HTTP/" <> http_version] ->
        {:ok,
         struct!(data,
           request:
             struct!(request,
               method: String.downcase(method),
               uri: uri,
               http_version: http_version
             )
         )}

      _ ->
        {:error, :invalid}
    end
  end

  defp parse_body(%Data{request: %Request{content_length: nil}, acc: ""} = data) do
    {:ok, {:complete, data}}
  end

  defp parse_body(
         %Data{request: %Request{content_length: content_length}, acc: acc} =
           data
       )
       when content_length > byte_size(acc) do
    {:ok, {:incomplete, data}}
  end

  defp parse_body(
         %Data{
           request: %Request{content_length: content_length} = request,
           acc: acc
         } = data
       ) do
    <<head::binary-size(content_length), tail::bits()>> = acc

    {:ok,
     {:complete,
      struct!(data, request: struct!(request, body: head), acc: tail)}}
  end

  defp parse_headers(%Data{acc: acc} = data) do
    case String.split(acc, @clrf, parts: 2) do
      [header_line, tail] ->
        decode_header(struct!(data, acc: tail), header_line)

      [^acc] ->
        {:ok, :incomplete}
    end
  end

  defp parse_request_line(%Data{acc: acc} = data) do
    case String.split(acc, @clrf, parts: 2) do
      [request_line, tail] ->
        decode_request_line(struct!(data, acc: tail), request_line)

      [^acc] ->
        {:ok, :incomplete}
    end
  end
end
