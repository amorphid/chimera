defmodule Chimera.HTTPClient.RequesterTest do
  use ExUnit.Case, async: true

  alias Chimera.HTTP.Response
  alias Chimera.HTTPClient
  alias Chimera.HTTPServer
  alias Chimera.HTTPServer.Data

  defmodule SendTimeoutProtocol do
    def send({:sslsocket, _, _}, encoded_request)
        when is_binary(encoded_request) do
      {:error, :timeout}
    end
  end

  setup do
    {:ok, server_pid} =
      HTTPServer.start_link(%{accept_timeout: 1, portno: 0}, name: nil)

    %{listen_socket: {_, _, {tcp_port, _}}} = :sys.get_state(server_pid)
    {:ok, portno} = :inet.port(tcp_port)
    %{portno: portno, server_pid: server_pid}
  end

  describe "GET w/ valid URI" do
    test "returns status code 200", %{portno: portno} do
      {:ok, %Response{status_code: actual}} =
        HTTPClient.get("https://localhost:#{portno}")

      expected = 200
      assert actual == expected
    end
  end

  describe "GET w/ invalid URI" do
    test "returns nxdomain error" do
      actual = HTTPClient.get("https://invalid.url")
      expected = {:error, :nxdomain}
      assert actual == expected
    end
  end

  describe "GET w/ send timeout" do
    test "returns send_timeout error ", %{
      portno: portno
    } do
      actual =
        HTTPClient.get(
          "https://localhost:#{portno}",
          [protocol_module: SendTimeoutProtocol, send_timeout: 0],
          :infinity
        )

      expected = {:error, :send_timeout}
      assert actual == expected
    end
  end

  describe "GET w/ connect timeout" do
    test "returns connect timeout error ", %{portno: portno} do
      actual =
        HTTPClient.get(
          "https://localhost:#{portno}",
          [connect_timeout: 0],
          :infinity
        )

      expected = {:error, :connect_timeout}
      assert actual == expected
    end
  end

  describe "GET w/ receive timeout" do
    test "returns receive timeout error ", %{portno: portno} do
      actual =
        HTTPClient.get(
          "https://localhost:#{portno}",
          [receive_timeout: 0],
          :infinity
        )

      expected = {:error, :receive_timeout}
      assert actual == expected
    end
  end
end
