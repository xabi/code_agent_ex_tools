defmodule CodeAgentExToolsTest do
  use ExUnit.Case
  doctest CodeAgentExTools

  test "greets the world" do
    assert CodeAgentExTools.hello() == :world
  end
end
