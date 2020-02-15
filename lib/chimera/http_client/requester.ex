defmodule Chimera.HTTPClient.Requester do
  @moduledoc """
  http://www.plantuml.com/plantuml/uml/dP7DIiSm4CJlUOhbVnJw0XwaIWyAtZogbD3TWv2ac8-3R--cNQfaMmgzb6HcVfrbqwTiOoxU6JvaWXTqPEHyUvocuelZyqTuOwaaUFqA18FDzWOs0GTMlSfLtT21fXcFiDKy8P_98iNKKY8BekRK69kYxTOypVZJTbHjlq01xFobt-y-eUiUP8drMwzwIt0FYGAEaRuBfMoCJZ0dmoWK5td4fN8lSrWQY73qSpo3rQfLhGv8vtz95pQ1wrNDGxLCuyfisrqF9kxrt_FJcvu25kz-0G00
  """

  alias Chimera.HTTP.Response

  @behaviour :gen_statem

  @clrf "\r\n"
  @default_connect_timeout 8_000
  @default_send_timeout :infinity

  defmodule Data do
    defstruct acc: "",
              connect_timeout: nil,
              from: nil,
              protocol_module: nil,
              receive_timeout: nil,
              response: %Response{},
              send_timeout: nil,
              socket: nil
  end

  #######
  # API #
  #######

  def start_link(args) do
    :gen_statem.start_link(__MODULE__, args, [])
  end

  #############
  # Callbacks #
  #############

  def callback_mode() do
    :handle_event_function
  end

  def handle_event(
        :info,
        {:ssl, socket, msg},
        :AccBodyData,
        %Data{acc: acc, socket: socket} = data
      ) do
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
      ) do
    acc2 = acc <> msg
    data2 = struct!(data, acc: acc2)

    {:next_state, :DecodeHeadersData, data2,
     {:next_event, :internal, :decode_data}}
  end

  def handle_event(
        :info,
        {:ssl, socket, msg},
        :AccStatusLineData,
        %Data{acc: acc, socket: socket} = data
      ) do
    acc2 = acc <> msg
    data2 = struct!(data, acc: acc2)

    {:next_state, :DecodeStatusLineData, data2,
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
        %Data{
          from: {pid, ref},
          protocol_module: protocol_module,
          receive_timeout: receive_timeout,
          socket: socket
        } = data
      ) do
    case decode_body(data) do
      {:ok, {:complete, %Data{response: %Response{} = response} = data}} ->
        send(pid, {{:ok, response}, ref})
        {:stop, :normal, data}

      {:ok, {:incomplete, %Data{} = data}} ->
        case protocol_module.setopts(socket, active: :once) do
          :ok ->
            {:next_state, :AccBodyData, data, receive_timeout}

          {:error, _} = error ->
            _ = send(pid, {error, ref})
            {:stop, :normal, data}
        end
    end
  end

  def handle_event(
        :internal,
        :decode_data,
        :DecodeHeadersData,
        %Data{
          from: {pid, ref},
          protocol_module: protocol_module,
          receive_timeout: receive_timeout,
          socket: socket
        } = data
      ) do
    case decode_headers(data) do
      {:ok, {:complete, %Data{} = data}} ->
        {:next_state, :DecodeBodyData, data,
         {:next_event, :internal, :decode_data}}

      {:ok, {:incomplete, %Data{} = data}} ->
        case protocol_module.setopts(socket, active: :once) do
          :ok ->
            {:next_state, :AccHeadersData, data, receive_timeout}

          {:error, _} = error ->
            _ = send(pid, {error, ref})
            {:stop, :normal, data}
        end
    end
  end

  def handle_event(
        :internal,
        :decode_data,
        :DecodeStatusLineData,
        %Data{
          acc: acc,
          from: {pid, ref},
          protocol_module: protocol_module,
          receive_timeout: receive_timeout,
          response: %Response{} = response,
          socket: socket
        } = data
      ) do
    case String.split(acc, @clrf, parts: 2) do
      [status_line_str, tail] ->
        [http_version_str, status_code_str, "OK"] =
          String.split(status_line_str, " ")

        "HTTP/" <> http_version = http_version_str
        {status_code, ""} = Integer.parse(status_code_str)

        response2 =
          struct!(response, http_version: http_version, status_code: status_code)

        data2 = struct!(data, acc: tail, response: response2)

        {:next_state, :DecodeHeadersData, data2,
         {:next_event, :internal, :decode_data}}

      [^acc] ->
        case protocol_module.setopts(socket, active: :once) do
          :ok ->
            data2 = struct!(data, acc: acc)
            {:next_state, :AccStatusLineData, data2, receive_timeout}

          {:error, _} = error ->
            _ = send(pid, {error, ref})
            {:stop, :normal, data}
        end
    end
  end

  def handle_event(
        :internal,
        {:send_request, {method, unparsed_uri}},
        :Idle,
        %Data{
          from: {pid, ref},
          connect_timeout: connect_timeout,
          protocol_module: protocol_module,
          receive_timeout: receive_timeout,
          send_timeout: send_timeout
        } = data
      ) do
    uri =
      case URI.parse(unparsed_uri) do
        %URI{path: nil} = uri ->
          struct!(uri, path: "/")

        %URI{} = uri ->
          uri
      end

    case open_connection(uri, connect_timeout, send_timeout, protocol_module) do
      {:ok, {protocol_module, socket}} ->
        {:ok, encoded_request} = encode_request(method, uri)

        case protocol_module.send(socket, encoded_request) do
          :ok ->
            data2 =
              struct!(data, protocol_module: protocol_module, socket: socket)

            {:next_state, :AccStatusLineData, data2, receive_timeout}

          {:error, :timeout} ->
            error = {:error, :send_timeout}
            _ = send(pid, {error, ref})
            {:stop, :normal, data}

          {:error, _} = error ->
            _ = send(pid, {error, ref})
            {:stop, :normal, data}
        end

      {:error, :timeout} ->
        error = {:error, :connect_timeout}
        _ = send(pid, {error, ref})
        {:stop, :normal, data}

      {:error, _} = error ->
        _ = send(pid, {error, ref})
        {:stop, :normal, data}
    end
  end

  def handle_event(
        :timeout,
        _,
        state,
        %Data{from: {pid, ref}} = data
      )
      when state in [:AccBodyData, :AccHeadersData, :AccStatusLineData] do
    error = {:error, :receive_timeout}
    _ = send(pid, {error, ref})
    {:stop, :normal, data}
  end

  def init({from, method, unparsed_uri, opts, receive_timeout}) do
    connect_timeout =
      Keyword.get(opts, :connect_timeout, @default_connect_timeout)

    receive_timeout = Keyword.get(opts, :receive_timeout, receive_timeout)
    send_timeout = Keyword.get(opts, :send_timeout, @default_send_timeout)
    protocol_module = Keyword.get(opts, :protocol_module, nil)

    {:ok, :Idle,
     %Data{
       from: from,
       connect_timeout: connect_timeout,
       protocol_module: protocol_module,
       receive_timeout: receive_timeout,
       send_timeout: send_timeout
     }, {:next_event, :internal, {:send_request, {method, unparsed_uri}}}}
  end

  ###########
  # Private #
  ###########

  defp decode_body(
         %Data{
           acc: acc,
           response: %Response{content_length: content_length} = response
         } = data
       )
       when is_integer(content_length) do
    # 1 = data
    case byte_size(acc) do
      acc_length when acc_length == content_length ->
        response2 = struct!(response, body: acc)
        data2 = struct!(data, acc: "", response: response2)
        {:ok, {:complete, data2}}

      acc_length when acc_length < content_length ->
        {:ok, {:incomplete, data}}
    end
  end

  defp decode_body(
         %Data{acc: "", response: %Response{content_length: nil}} = data
       ) do
    {:ok, {:complete, data}}
  end

  defp decode_headers(%Data{acc: @clrf} = data) do
    acc = ""
    data2 = struct!(data, acc: acc)
    {:ok, {:complete, data2}}
  end

  defp decode_headers(
         %Data{acc: acc, response: %Response{headers: headers} = response} =
           data
       ) do
    case String.split(acc, @clrf, parts: 2) do
      [header_line, tail] when header_line != "" ->
        [key, value] = String.split(header_line, ": ")

        case String.downcase(key) do
          "content-length" ->
            {content_length, ""} = Integer.parse(value)
            headers2 = headers ++ [{key, value}]

            response2 =
              struct!(response,
                content_length: content_length,
                headers: headers2
              )

            data2 = struct!(data, acc: tail, response: response2)
            decode_headers(data2)

          _ ->
            headers2 = headers ++ [{key, value}]
            response2 = struct!(response, headers: headers2)
            data2 = struct!(data, acc: tail, response: response2)
            decode_headers(data2)
        end

      ["", tail] ->
        data2 = struct!(data, acc: tail)
        {:ok, {:complete, data2}}

      [^acc] ->
        {:ok, {:incomplete, data}}
    end
  end

  defp encode_headers(headers) do
    encode_headers(headers, "")
  end

  defp encode_headers([{key, value} | tail], acc) do
    acc2 = acc <> key <> ": " <> value <> @clrf
    encode_headers(tail, acc2)
  end

  defp encode_headers([], acc) do
    acc
  end

  defp encode_request(method, %URI{authority: authority, path: path}) do
    status_line = method <> " " <> path <> " " <> "HTTP/1.1"
    user_agent = "#{__MODULE__}/#{Application.fetch_env!(:chimera, :version)}"

    headers = [
      {"Host", authority},
      {"User-Agent", user_agent},
      {"Accept", "*/*"}
    ]

    encoded_request = status_line <> @clrf <> encode_headers(headers) <> @clrf
    {:ok, encoded_request}
  end

  defp open_connection(
         %URI{host: host_as_str, port: port, scheme: scheme},
         connect_timeout,
         send_timeout,
         protocol_module
       ) do
    protocol_module2 =
      case scheme do
        "https" -> :ssl
      end

    host = String.to_charlist(host_as_str)
    opts = [:binary, active: :once, reuseaddr: true, send_timeout: send_timeout]

    case protocol_module2.connect(host, port, opts, connect_timeout) do
      {:ok, socket} ->
        if protocol_module do
          {:ok, {protocol_module, socket}}
        else
          {:ok, {protocol_module2, socket}}
        end

      {:error, _} = error ->
        error
    end
  end
end
