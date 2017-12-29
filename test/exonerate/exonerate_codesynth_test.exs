defmodule ExonerateCodesynthBasicTest.Helper do
  defmacro codesynth_match(map, code) do
    quote do
      get_route = unquote(map)
      get_code = unquote(code) |> Code.format_string! |> Enum.join
      test_code = Exonerate.Codesynth.validator_string("test", get_route) |> Code.format_string! |> Enum.join
      assert test_code == get_code
    end
  end
end

defmodule ExonerateCodesynthBasicTest do
  use ExUnit.Case
  import ExonerateCodesynthBasicTest.Helper

  @tag :exonerate_codesynth
  test "boolean json schemas are always valid" do
    codesynth_match true, "def validate_test(val), do: :ok"
    codesynth_match false, "def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}"
  end

  @tag :exonerate_codesynth
  test "string json schemas generate correct code" do
    codesynth_match %{"type" => "string"},
      """
        def validate_test(val) when is_binary(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """

    codesynth_match %{"type" => "string", "minLength" => 3, "maxLength" => 5},
      """
        def validate_test(val) when is_binary(val), do: [Exonerate.Checkers.check_minlength(val, 3), Exonerate.Checkers.check_maxlength(val, 5)] |> Exonerate.error_reduction()
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """

    codesynth_match %{"type" => "string", "pattern" => "test"},
      """
        @pattern_test Regex.compile("test") |> elem(1)

        def validate_test(val) when is_binary(val), do: Exonerate.Checkers.check_regex(@pattern_test, val)
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """

    codesynth_match %{"type" => "string", "minLength" => 3, "pattern" => "test", "format" => "uri"},
      """
        @pattern_test Regex.compile("test") |> elem(1)

        def validate_test(val) when is_binary(val), do: [Exonerate.Checkers.check_regex(@pattern_test, val), Exonerate.Checkers.check_format_uri(val), Exonerate.Checkers.check_minlength(val, 3)] |> Exonerate.error_reduction
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
  end

  @tag :exonerate_codesynth
  test "integer json schemas generate correct code" do
    codesynth_match %{"type" => "integer"},
      """
        def validate_test(val) when is_integer(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
    codesynth_match %{"type" => "integer", "multipleOf" => 3},
      """
        def validate_test(val) when is_integer(val) and (rem(val,3) != 0), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
    codesynth_match %{"type" => "integer", "multipleOf" => 3, "minimum" => 3},
      """
        def validate_test(val) when is_integer(val) and (rem(val,3) != 0), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val) and (val < 3), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
    codesynth_match %{"type" => "integer", "minimum" => 3, "maximum" => 7},
      """
        def validate_test(val) when is_integer(val) and (val < 3), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val) and (val > 7), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
    codesynth_match %{"type" => "integer", "minimum" => 3, "exclusiveMinimum" => true, "maximum" => 7},
      """
        def validate_test(val) when is_integer(val) and (val <= 3), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val) and (val > 7), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
        def validate_test(val) when is_integer(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
  end

  @tag :exonerate_codesynth
  test "boolean json schemas generate correct code" do
    codesynth_match %{"type" => "boolean"},
      """
        def validate_test(val) when is_boolean(val), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
  end

  @tag :exonerate_codesynth
  test "nil json schemas generate correct code" do
    codesynth_match %{"type" => "null"},
      """
        def validate_test(nil), do: :ok
        def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      """
  end

  @tag :exonerate_codesynth
  test "basic object parameters work" do
    codesynth_match %{"type" => "object"},
    """
      def validate_test(val) when is_map(val), do: :ok
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}}},
    """
      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test(val) when is_map(val), do: validate_test_test1(val["test1"])
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}, "test2" => %{"type" => "integer"}}},
    """
      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test2(val) when is_integer(val), do: :ok
      def validate_test_test2(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        qmatch =
         case k do
           "test1" -> validate_test_test1(v)
           "test2" -> validate_test_test2(v)
           _ -> :ok
         end
      end

      def validate_test(val) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}}, "additionalProperties" => false},
    """
      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        qmatch = case k do
          "test1" -> {validate_test_test1(v), true}
          _ -> {:ok, false}
        end

        {result, matched} = qmatch
        if matched, do: result, else: {:error, \"does not conform to JSON schema\"}
      end

      def validate_test(val) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}}, "additionalProperties" => %{"type" => "integer"}},
    """
      def validate_test__additionalProperties(val) when is_integer(val), do: :ok
      def validate_test__additionalProperties(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        qmatch = case k do
          "test1" -> {validate_test_test1(v), true}
          _ -> {:ok, false}
        end

        {result, matched} = qmatch
        if matched, do: result, else: validate_test__additionalProperties(v)

      end

      def validate_test(val) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}, "test2" => %{"type" => "integer"}}, "required" => ["test1"]},
    """
      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test2(val) when is_integer(val), do: :ok
      def validate_test_test2(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        qmatch = case k do
          "test1" -> validate_test_test1(v)
          "test2" -> validate_test_test2(v)
          _ -> :ok
        end
      end

      def validate_test(val=%{"test1" => _}) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val) when is_map(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "minProperties" => 3, "maxProperties" => 5},
    """
      def validate_test(val) when is_map(val), do: [Exonerate.Checkers.check_minproperties(val, 3), Exonerate.Checkers.check_maxproperties(val, 5)] |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}, "test2" => %{"type" => "integer"}}, "dependencies" => %{"test1" => ["test2"] }},
    """
      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test2(val) when is_integer(val), do: :ok
      def validate_test_test2(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        qmatch = case k do
          "test1" -> validate_test_test1(v)
          "test2" -> validate_test_test2(v)
          _ -> :ok
        end
      end

      def validate_test(val) when is_map(val), do: ([check_dependencies(val, "test1", ["test2"]) | Enum.map(val, &__MODULE__.validate_test__each/1)]) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}}, "patternProperties" => %{"testp" => %{"type" => "integer"}}},
    """
      @patternprop_test_0 Regex.compile("testp") |> elem(1)

      def validate_test__pattern_0(val) when is_integer(val), do: :ok
      def validate_test__pattern_0(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        pmatch = if Regex.match?(@patternprop_test_0, k), do: validate_test__pattern_0(v), else: :ok

        qmatch = case k do
          "test1" -> validate_test_test1(v)
          _ -> :ok
        end

        [qmatch, pmatch] |> Exonerate.error_reduction()

      end

      def validate_test(val) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    #test collision between extra parameter restrictions and regex patterns
    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}}, "additionalProperties" => false, "patternProperties" => %{"testp" => %{"type" => "integer"}}},
    """
      @patternprop_test_0 Regex.compile("testp") |> elem(1)

      def validate_test__pattern_0(val) when is_integer(val), do: :ok
      def validate_test__pattern_0(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        pmatch = if Regex.match?(@patternprop_test_0, k), do: {validate_test__pattern_0(v), true}, else: {:ok, false}

        qmatch = case k do
          "test1" -> {validate_test_test1(v), true}
          _ -> {:ok, false}
        end

        {result, matched} = [qmatch, pmatch] |> Enum.unzip()

        if Enum.any?(matched), do: result |> Exonerate.error_reduction(), else: {:error, "does not conform to JSON schema"}
      end

      def validate_test(val) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    #test collision between specified extra parameters and regex patterns
    codesynth_match %{"type" => "object", "properties" => %{"test1" => %{"type" => "string"}}, "additionalProperties" => %{"type" => "integer"}, "patternProperties" => %{"testp" => %{"type" => "integer"}}},
    """
      @patternprop_test_0 Regex.compile("testp") |> elem(1)

      def validate_test__additionalProperties(val) when is_integer(val), do: :ok
      def validate_test__additionalProperties(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__pattern_0(val) when is_integer(val), do: :ok
      def validate_test__pattern_0(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_test1(val) when is_binary(val), do: :ok
      def validate_test_test1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__each({k, v}) do
        pmatch = if Regex.match?(@patternprop_test_0, k), do: {validate_test__pattern_0(v), true}, else: {:ok, false}

        qmatch = case k do
          "test1" -> {validate_test_test1(v), true}
          _ -> {:ok, false}
        end

        {result, matched} = [qmatch, pmatch] |> Enum.unzip()

        if Enum.any?(matched), do: result |> Exonerate.error_reduction(), else: validate_test__additionalProperties(v)
      end

      def validate_test(val) when is_map(val), do: Enum.map(val, &__MODULE__.validate_test__each/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """
  end

  @tag :exonerate_codesynth
  test "basic array parameters work" do
    codesynth_match %{"type" => "array"},
    """
      def validate_test(val) when is_list(val), do: :ok
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "array", "items" => %{"type" => "string"}},
    """
      def validate_test__forall(val) when is_binary(val), do: :ok
      def validate_test__forall(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test(val) when is_list(val), do: Enum.map(val, &__MODULE__.validate_test__forall/1) |> Exonerate.error_reduction
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "array", "items" => [%{"type" => "string"}, %{"type" => "integer"}]},
    """
      def validate_test_0(val) when is_binary(val), do: :ok
      def validate_test_0(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_1(val) when is_integer(val), do: :ok
      def validate_test_1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__all(val) do
        val |> Enum.zip([&__MODULE__.validate_test_0/1, &__MODULE__.validate_test_1/1])
            |> Enum.map(fn {a, f} -> f.(a) end)
            |> Exonerate.error_reduction
      end

      def validate_test(val) when is_list(val), do: validate_test__all(val)
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "array", "minItems" => 3},
    """
      def validate_test(val) when is_list(val) and length(val) < 3, do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      def validate_test(val) when is_list(val), do: :ok
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "array", "maxItems" => 7},
    """
      def validate_test(val) when is_list(val) and length(val) > 7, do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      def validate_test(val) when is_list(val), do: :ok
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "array", "uniqueItems" => true},
    """
      def validate_test(val) when is_list(val), do: Exonerate.Checkers.check_unique(val)
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """

    codesynth_match %{"type" => "array", "items" => [%{"type" => "string"}, %{"type" => "integer"}], "additionalItems" => false},
    """
      def validate_test_0(val) when is_binary(val), do: :ok
      def validate_test_0(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test_1(val) when is_integer(val), do: :ok
      def validate_test_1(val), do: {:error, "\#{inspect val} does not conform to JSON schema"}

      def validate_test__all(val) do
        val |> Enum.zip([&__MODULE__.validate_test_0/1, &__MODULE__.validate_test_1/1])
            |> Enum.map(fn {a, f} -> f.(a) end)
            |> Exonerate.error_reduction
      end

      def validate_test(val) when is_list(val) and (length(val) > 2), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
      def validate_test(val) when is_list(val), do: validate_test__all(val)
      def validate_test(val), do: {:error, \"\#{inspect(val)} does not conform to JSON schema\"}
    """
  end

end
