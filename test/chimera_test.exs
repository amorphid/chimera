defmodule ChimeraTest do
  use ExUnit.Case
  doctest Chimera

  test "greets the world" do
    assert Chimera.hello() == :world
  end
end
