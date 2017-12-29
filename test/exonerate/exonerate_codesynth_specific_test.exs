defmodule ExonerateCodesynthSpecificTest.Helper do
  defmacro codesynth_match(map, code) do
    quote do
      get_route = unquote(map)
      get_code = unquote(code) |> Code.format_string! |> Enum.join
      test_code = Exonerate.Codesynth.validator_string("test", get_route) |> Code.format_string! |> Enum.join

      assert test_code == get_code
    end
  end
end

defmodule ExonerateCodesynthSpecificTest do
  use ExUnit.Case, async: true
  import ExonerateCodesynthSpecificTest.Helper

  @tag :exonerate_codesynth
  test "json schemas that don't specify array with array parameters build properly" do
    codesynth_match %{"items" => [%{}], "additionalItems" => %{"type" => "integer"}},
      """
      def validate_test__additionalItems(val) when is_integer(val), do: :ok
      def validate_test__additionalItems(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_0(val), do: :ok

      def validate_test__all(val) do
        Exonerate.Checkers.check_additionalitems(val, [&__MODULE__.validate_test_0/1], &__MODULE__.validate_test__additionalItems/1)
      end

      def validate_test(val) when is_list(val), do: validate_test__all(val)
      def validate_test(val), do: :ok
      """
  end
end
