defmodule ExaggerateCodesynthComponentTest do
  use ExUnit.Case, async: true

  doctest Exaggerate.Codesynth

  test "get_defs correctly pulls definition values" do
    assert Exaggerate.Codesynth.get_defs("""
    defmodule A do
      def a do
      end
    end
    """ |> Code.format_string!) == ["a"]

  end
end
