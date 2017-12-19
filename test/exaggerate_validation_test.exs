defmodule ExaggerateValidationComponentTest do
  use ExUnit.Case, async: true

  defmodule OneReqParam do
    import Exaggerate.Validation.Helpers

    validate_keys [:param],[]
    string_parameter :param
  end

  test "one required parameter" do
    assert OneReqParam.is_valid?(%{"param" => "test"}) == {:ok}
    assert OneReqParam.is_valid?(%{}) == {:error, OneReqParam, "required key param is missing"}
    assert OneReqParam.is_valid?(%{"param" => %{"test" => "test"}}) == {:error, OneReqParam, "param key's value is not a string, got %{\"test\" => \"test\"}"}
  end

  defmodule TwoReqParam do
    import Exaggerate.Validation.Helpers

    validate_keys [:param1, :param2],[]
    string_parameter :param1
    string_parameter :param2
  end

  test "two required parameters" do
    assert TwoReqParam.is_valid?(%{"param1" => "test", "param2" => "test"}) == {:ok}
    assert TwoReqParam.is_valid?(%{"param1" => %{"test" => "test"}, "param2" => "test"}) == {:error, TwoReqParam, "param1 key's value is not a string, got %{\"test\" => \"test\"}"}
    assert TwoReqParam.is_valid?(%{"param1" => "test"}) == {:error, TwoReqParam, "required key param2 is missing"}
    assert TwoReqParam.is_valid?(%{"param2" => "test"}) == {:error, TwoReqParam, "required key param1 is missing"}
  end

  defmodule OneOptParam do
    import Exaggerate.Validation.Helpers

    validate_keys [],[:param]
    string_parameter :param
  end

  test "one optional parameter" do
    assert (OneOptParam.is_valid?(%{"param" => "test"}) == {:ok})
    assert (OneOptParam.is_valid?(%{}) == {:ok})
  end

  defmodule FurtherParam do
    import Exaggerate.Validation.Helpers

    validate_keys [:param],[]
    string_parameter :param

    def further_validation(%{"param" => "ok"}), do: {:ok}
    def further_validation(%{"param" => _}), do: {:error}
  end

  test "further validation method" do
    assert FurtherParam.is_valid?(%{"param" => "ok"}) == {:ok}
    assert FurtherParam.is_valid?(%{"param" => "huh"}) == {:error}
    assert FurtherParam.is_valid?(%{}) == {:error, FurtherParam, "required key param is missing"} #this error should take precedence.
  end

  defmodule VersionParam do
    import Exaggerate.Validation.Helpers

    validate_keys [:param], []
    version_parameter :param
  end

  test "version parameter" do
    assert VersionParam.is_valid?(%{"param" => "3.0.1"}) == {:ok}
    #assert Version.Param.is_valid?(%{"param" => "nonsense"}) == {:error, VersionParam, "param key is not a semantic version"}
    assert VersionParam.is_valid?(%{"param" => %{"test" => "test"}}) == {:error, VersionParam, "param key's value is not a semantic version, got %{\"test\" => \"test\"}"}
  end

  defmodule BooleanParam do
    import Exaggerate.Validation.Helpers

    validate_keys [:param], []
    boolean_parameter :param
  end

  test "boolean parameter" do
    assert BooleanParam.is_valid?(%{"param" => true}) == {:ok}
    assert BooleanParam.is_valid?(%{"param" => "true"}) == {:error, BooleanParam, "param key's value is not boolean, got \"true\""}
    assert BooleanParam.is_valid?(%{"param" => %{"test" => "test"}}) == {:error, BooleanParam, "param key's value is not boolean, got %{\"test\" => \"test\"}"}
  end

  defmodule UrlParam do
    import Exaggerate.Validation.Helpers

    validate_keys [:param], []
    url_parameter :param
  end

  test "url parameter" do
    assert UrlParam.is_valid?(%{"param" => "https://github.com"}) == {:ok}
    assert UrlParam.is_valid?(%{"param" => "telnet://blinkenlights.nl:4300"}) == {:ok}
    assert UrlParam.is_valid?(%{"param" => true}) == {:error, UrlParam, "param key's value is not a url, got true"}
    assert UrlParam.is_valid?(%{"param" => "true"}) == {:error, UrlParam, "url \"true\" does not contain a scheme"}
    assert UrlParam.is_valid?(%{"param" => %{"test" => "test"}}) == {:error, UrlParam, "param key's value is not a url, got %{\"test\" => \"test\"}"}
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
  test "verifying swaggerfile succeeds on a file that exists in the root directory" do
    assert Exaggerate.Codesynth.swaggerfile_exists?("mix.exs")
  end
  test "verifying swaggerfile succeeds on a file that is a json file" do
    assert Exaggerate.Codesynth.swaggerfile_exists?("basic.json")
  end

  test "invalid json fails on swagger validation test" do
    refute Exaggerate.Codesynth.swaggerfile_isvalid?("basic.json") == {:ok}
  end

end

defmodule ExaggeratePetshopValidationTest do
  use ExUnit.Case

  @rootpath File.cwd!

  setup_all do
    Path.join(@rootpath, "swagger.json")
      |> File.write!(HTTPoison.get!("http://petstore.swagger.io/v2/swagger.json").body)
    on_exit(fn -> clean_swagger_file() end)
  end

  defp clean_swagger_file, do: Path.join(@rootpath, "swagger.json") |> File.rm!

  test "verifying that the basic swaggerfile passes the validation" do
    assert Exaggerate.Codesynth.swaggerfile_isvalid?("swagger.json")
  end
end
