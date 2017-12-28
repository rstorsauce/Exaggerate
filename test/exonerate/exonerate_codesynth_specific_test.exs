defmodule ExonerateCodesynthSpecificTest.Helper do
  defmacro codesynth_match(map, code) do
    quote do
      get_route = unquote(map)
      get_code = unquote(code) |> Code.format_string! |> Enum.join

      assert Exonerate.Codesynth.validator("test", get_route) == get_code
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
      def validate_test_0(_val), do: :ok
      def validate_test_0(val), do: {:error, "\#{inspect(val)} does not conform to JSON schema"}

      def validate_test_all(val) when is_list(val) do
      val
      |> Enum.zip(val, [&__MODULE__.validate_test_0/1])
      |> Enum.map(fn {a, f} -> f.(a) end)
      |> Exonerate.error_reduction()
      end

      def validate_test(val) when is_list(val), do: validate_test_all(val)
      def validate_test(val), do: :ok
      """
  end
end
