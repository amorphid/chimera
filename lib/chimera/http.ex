defmodule Chimera.HTTP do
  alias Chimera.HTTP.Request
  alias Chimera.Metabolizers.Root

  @methods %{
    "get" => :get
  }

  @metabolizers %{
    ~r/^\/$/ => Root
  }

  def get_route_from_request(%Request{method: case_insensitive_method, uri: uri}) do
    {_, metabolizer} =
      Enum.find(@metabolizers, fn {key, _value} -> uri =~ key end)

    method =
      case_insensitive_method
      |> String.downcase()
      |> case do
        method ->
          Map.fetch!(@methods, method)
      end

    {metabolizer, method}
  end
end
