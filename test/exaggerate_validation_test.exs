defmodule ExaggerateValidationComponentTest do
  use ExUnit.Case, async: true
  import Exaggerate.Validation.Helpers

  defmodule OneReqParam do
    validate_keys [:param],[]
    string_parameter :param
  end

  test "one required parameter" do
    assert OneReqParam.validate(%{"param" => "test"}) == :ok
    assert OneReqParam.validate(%{}) == {:error, OneReqParam, "required key param is missing"}
    assert OneReqParam.validate(%{"param" => %{"test" => "test"}}) == {:error, OneReqParam, "param key's value is not a string, got %{\"test\" => \"test\"}"}
  end

  defmodule TwoReqParam do
    validate_keys [:param1, :param2],[]
    string_parameter :param1
    string_parameter :param2
  end

  test "two required parameters" do
    assert TwoReqParam.validate(%{"param1" => "test", "param2" => "test"}) == :ok
    assert TwoReqParam.validate(%{"param1" => %{"test" => "test"}, "param2" => "test"}) == {:error, TwoReqParam, "param1 key's value is not a string, got %{\"test\" => \"test\"}"}
    assert TwoReqParam.validate(%{"param1" => "test"}) == {:error, TwoReqParam, "required key param2 is missing"}
    assert TwoReqParam.validate(%{"param2" => "test"}) == {:error, TwoReqParam, "required key param1 is missing"}
  end

  defmodule OneOptParam do
    validate_keys [],[:param]
    string_parameter :param
  end

  test "one optional parameter" do
    assert (OneOptParam.validate(%{"param" => "test"}) == :ok)
    assert (OneOptParam.validate(%{}) == :ok)
  end

  defmodule FurtherParam do
    validate_keys [:param],[]
    string_parameter :param

    def further_validation(%{"param" => "ok"}), do: :ok
    def further_validation(%{"param" => _}), do: {:error}
  end

  test "further validation method" do
    assert FurtherParam.validate(%{"param" => "ok"}) == :ok
    assert FurtherParam.validate(%{"param" => "huh"}) == {:error}
    assert FurtherParam.validate(%{}) == {:error, FurtherParam, "required key param is missing"} #this error should take precedence.
  end

  defmodule VersionParam do
    validate_keys [:param], []
    version_parameter :param
  end

  test "version parameter" do
    assert VersionParam.validate(%{"param" => "3.0.1"}) == :ok
    #assert Version.Param.validate(%{"param" => "nonsense"}) == {:error, VersionParam, "param key is not a semantic version"}
    assert VersionParam.validate(%{"param" => %{"test" => "test"}}) == {:error, VersionParam, "param key's value is not a semantic version, got %{\"test\" => \"test\"}"}
  end

  defmodule BooleanParam do
    validate_keys [:param], []
    boolean_parameter :param
  end

  test "boolean parameter" do
    assert BooleanParam.validate(%{"param" => true}) == :ok
    assert BooleanParam.validate(%{"param" => "true"}) == {:error, BooleanParam, "param key's value is not boolean, got \"true\""}
    assert BooleanParam.validate(%{"param" => %{"test" => "test"}}) == {:error, BooleanParam, "param key's value is not boolean, got %{\"test\" => \"test\"}"}
  end

  defmodule UrlParam do
    validate_keys [:param], []
    url_parameter :param
  end

  test "url parameter" do
    assert UrlParam.validate(%{"param" => "https://github.com"}) == :ok
    assert UrlParam.validate(%{"param" => "telnet://blinkenlights.nl:4300"}) == :ok
    assert UrlParam.validate(%{"param" => true}) == {:error, UrlParam, "param key's value is not a url, got true"}
    assert UrlParam.validate(%{"param" => "true"}) == {:error, UrlParam, "url \"true\" does not contain a scheme"}
    assert UrlParam.validate(%{"param" => %{"test" => "test"}}) == {:error, UrlParam, "param key's value is not a url, got %{\"test\" => \"test\"}"}
  end

end

defmodule ExaggerateBasicValidationTest do
  use ExUnit.Case, async: true
  doctest Mix.Tasks.Swagger

  @rootpath File.cwd!

  setup_all do
    Path.join(@rootpath, "basic.json")
      |> File.write!(~s({"basic":"test"}\n))
    on_exit(fn -> clean_basic_file() end)
  end

  defp clean_basic_file, do: Path.join(@rootpath, "basic.json") |> File.rm!

  test "verifying swaggerfile fails on empty string" do
    refute Exaggerate.Codesynth.swaggerfile_exists?("")
  end
  test "verifying swaggerfile fails on nonsense string" do
    refute Exaggerate.Codesynth.swaggerfile_exists?("naothuenoth")
  end
  test "verifying swaggerfile succeeds on normal string" do
    assert Exaggerate.Codesynth.swaggerfile_exists?("basic.json")
  end
end

defmodule ExaggeratePetstoreValidationTest do
  use ExUnit.Case

  test "verifying that the swaggerfile passes the validation" do
    assert Exaggerate.Validation.validate!("test/resources/petstore.json") == :ok
  end
end
