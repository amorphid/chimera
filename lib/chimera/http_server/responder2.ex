defmodule Chimera.HTTPServer.Responder2 do
  @moduledoc """
  http://www.plantuml.com/plantuml/uml/fP4n3u8m48LtViM5qOG_u63GC3WukQeX3NU32IsHjeF_tYjgBkK2WsxblVVr7TVQ1pE6QFk23u6Wt7TTjB7dyzMTwH791pZT7K5ZWYd1UE046qbBKl456-e6N8JUxXft98Cq-ZdoaGN9PzGOcyBeciE0ptb7qXOBSe0TILysDwYgdTf8_fqY-lzX2pXfBKwC3kYRcN54sDfXNCNqwdHR5f2sZ55j4lYtAb-yPiILsIIj1XFtn-lvAOkQ74RRlm00
  """

  alias Chimera.HTTP
  alias Chimera.HTTP.Request

  @clrf "\r\n"

  defmodule Data do
    defstruct acc: "",
              protocol_module: nil,
              request: %Request{},
              responder_active: :once,
              socket: nil
  end

  #######
  # API #
  #######

  def start_link(args) do
    :gen_statem.start_link(
      __MODULE__,
      args,
      []
    )
  end

  #############
  # Callbacks #
  #############

  def callback_mode(), do: :handle_event_function

  def handle_event(
        :info,
        {:ssl, socket, msg},
        :AccBodyData,
        %Data{acc: acc, socket: socket} = data
      )
      when is_binary(msg) do
    acc2 = acc <> msg
    data2 = struct!(data, acc: acc2)

    {:next_state, :DecodeBodyData, data2,
     {:next_event, :internal, :decode_data}}
  end

  def handle_event(
        :info,
        {:ssl, socket, msg},
        :AccHeadersData,
        %Data{acc: acc, socket: socket} = data
      )
      when is_binary(msg) do
    acc2 = acc <> msg
    data2 = struct!(data, acc: acc2)

    {:next_state, :DecodeHeadersData, data2,
     {:next_event, :internal, :decode_data}}
  end

  def handle_event(
        :info,
        {:ssl, socket, msg},
        :AccReqLineData,
        %Data{acc: acc, socket: socket} = data
      )
      when is_binary(msg) do
    acc2 = acc <> msg
    data2 = struct!(data, acc: acc2)

    {:next_state, :DecodeReqLineData, data2,
     {:next_event, :internal, :decode_data}}
  end

  def handle_event(
        :info,
        {:ssl_closed, socket},
        _,
        %Data{socket: socket} = data
      ) do
    {:stop, :normal, data}
  end

  def handle_event(
        :internal,
        :decode_data,
        :DecodeBodyData,
        %Data{protocol_module: protocol_module, socket: socket} = data
      ) do
    case decode_body(data) do
      {:ok, {:complete, %Data{request: %Request{} = request} = data}} ->
        {metabolizer_module, function} = HTTP.get_route_from_request(request)
        response = apply(metabolizer_module, function, [request])
        _ = protocol_module.send(socket, response)
        :ok = protocol_module.close(socket)
        {:stop, :normal, data}

      {:ok, {:incomplete, %Data{} = data}} ->
        :ok = protocol_module.setopts(socket, active: :once)
        {:next_state, :AccBodyData, data}
    end
  end

  def handle_event(
        :internal,
        :decode_data,
        :DecodeHeadersData,
        %Data{protocol_module: protocol_module, socket: socket} = data
      ) do
    case decode_headers(data) do
      {:ok, {:complete, %Data{} = data}} ->
        {:next_state, :DecodeBodyData, data,
         {:next_event, :internal, :decode_data}}

      {:ok, {:incomplete, %Data{} = data}} ->
        :ok = protocol_module.setopts(socket, active: :once)
        {:next_state, :AccHeadersData, data}
    end
  end

  def handle_event(
        :internal,
        :decode_data,
        :DecodeReqLineData,
        %Data{acc: acc, protocol_module: protocol_module, socket: socket} = data
      ) do
    case String.split(acc, @clrf, parts: 2) do
      [request_line, tail] ->
        [method, uri, "HTTP/1.1"] = String.split(request_line, " ")
        request = struct!(Request, method: method, uri: uri)
        data2 = struct!(data, acc: tail, request: request)

        {:next_state, :DecodeHeadersData, data2,
         {:next_event, :internal, :decode_data}}

      [^acc] ->
        :ok = protocol_module.setopts(socket, active: :once)
        {:next_state, :AccReqLineData, data}
    end
  end

  def init({:ssl, listen_socket, accept_timeout, responder_active}) do
    case :ssl.transport_accept(listen_socket, accept_timeout) do
      {:ok, tls_transposrt_client_socket} ->
        {:ok, client_socket} = :ssl.handshake(tls_transposrt_client_socket)

        data =
          struct!(Data,
            protocol_module: :ssl,
            responder_active: responder_active,
            socket: client_socket
          )

        :ssl.setopts(client_socket, active: :once)
        {:ok, :AccReqLineData, data}

      {:error, :timeout} ->
        :ignore

      {:error, error} ->
        {:stop, error}
    end
  end

  ###########
  # Private #
  ###########

  defp decode_body(
         %Data{
           acc: acc,
           request: %Request{content_length: content_length} = request
         } = data
       )
       when is_integer(content_length) do
    case byte_size(acc) do
      acc_length when acc_length == content_length ->
        request2 = struct!(request, body: acc)
        data2 = struct!(data, acc: "", response: request2)
        {:ok, {:complete, data2}}

      acc_length when acc_length < content_length ->
        {:ok, {:incomplete, data}}
    end
  end

  defp decode_body(
         %Data{acc: "", request: %Request{content_length: nil}} = data
       ) do
    {:ok, {:complete, data}}
  end

  defp decode_headers(%Data{acc: @clrf} = data) do
    acc = ""
    data2 = struct!(data, acc: acc)
    {:ok, {:complete, data2}}
  end

  defp decode_headers(
         %Data{acc: acc, request: %Request{headers: headers} = request} = data
       ) do
    case String.split(acc, @clrf, parts: 2) do
      [header_line, tail] when header_line != "" ->
        [key, value] = String.split(header_line, ": ")

        case String.downcase(key) do
          "content-length" ->
            {content_length, ""} = Integer.parse(value)
            headers2 = headers ++ [{key, value}]

            request2 =
              struct!(request,
                content_length: content_length,
                headers: headers2
              )

            data2 = struct!(data, acc: tail, request: request2)
            decode_headers(data2)

          _ ->
            headers2 = headers ++ [{key, value}]
            request2 = struct!(request, headers: headers2)
            data2 = struct!(data, acc: tail, request: request2)
            decode_headers(data2)
        end

      ["", tail] ->
        data2 = struct!(data, acc: tail)
        {:ok, {:complete, data2}}

      [^acc] ->
        {:ok, {:incomplete, data}}
    end
  end
end
