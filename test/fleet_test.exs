defmodule FleetTest do
  use ExUnit.Case
  doctest Fleet

  test "greets the world" do
    assert Fleet.hello() == :world
  end
end
