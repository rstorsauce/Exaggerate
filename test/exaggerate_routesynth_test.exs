
defmodule Codesynth.Helper do
  defmacro codesynth_match(map, code, verb, path) do
    quote do
      get_route = unquote(map)
      get_code = unquote(code) |> String.trim_trailing |> Code.format_string! |> Enum.join

      assert Exaggerate.Codesynth.Routesynth.build_route(unquote(verb), unquote(path), get_route, "TestModule") == get_code
    end
  end
end


defmodule ExaggerateCodesynthUnitTest do
  use ExUnit.Case
  doctest Exaggerate.Codesynth.Routesynth
  #some of these things can't be put into doctests because of too many quotation
  #marks which seems to confuse the compiler.

  test "get_params_list" do
    assert Exaggerate.Codesynth.Routesynth.get_params_list([%{"required" => false, "name" => "test"}]) == ",drop_nil_values(%{\"test\" => test})"
    assert Exaggerate.Codesynth.Routesynth.get_params_list([%{"required" => false, "name" => "test1"}, %{"required" => false, "name" => "test2"}]) == ",drop_nil_values(%{\"test1\" => test1,\"test2\" => test2})"
    assert Exaggerate.Codesynth.Routesynth.get_params_list([%{"required" => true, "name" => "test1"}, %{"required" => false, "name" => "test2"}]) == ",test1,drop_nil_values(%{\"test2\" => test2})"
  end
end

defmodule ExaggerateCodesynthIntegrationTest do
  import Codesynth.Helper
  use ExUnit.Case

  test "bare bones get" do

    codesynth_match(
      %{"operationId" => "barebones",
      "responses" => %{"default" => "success"}},
      """
      get "/barebones" do
        case TestModule.Web.Endpoint.barebones(conn) do
          _ -> send_formatted(conn, 200, "success")
        end
      end
      """,
      :get, "/barebones")

    codesynth_match(
      %{"operationId" => "barebones",
      "responses" => %{}},
      """
      get "/barebones" do
        case TestModule.Web.Endpoint.barebones(conn) do
          {:ok, content} -> send_formatted(conn, 200, content)
          _ -> send_resp(conn, 400, "")
        end
      end
      """,
      :get, "/barebones")

  end

  test "get with basic 404 error response" do

    codesynth_match(
      %{"operationId" => "e404",
      "responses" => %{"404" => %{"description" => "404 error"}}},
      """
      get "/e404" do
        case TestModule.Web.Endpoint.e404(conn) do
          # handles 404 error.
          {:error, 404, details} -> send_formatted(conn, 404, %{"404" => "404 error: " <> details})
          {:ok, content} -> send_formatted(conn, 200, content)
          _ -> send_resp(conn, 400, "")
        end
      end
      """,
      :get, "/e404")
  end

  test "get with basic 200 success override" do

    codesynth_match(
      %{"operationId" => "b200",
      "responses" => %{"200" => %{"description" => "general success"}}},
      """
      get "/b200" do
        case TestModule.Web.Endpoint.b200(conn) do
          # handles general success.
          {:ok, 200, details} -> send_formatted(conn, 200, %{"200" => "general success: " <> details})
          {:ok, content} -> send_formatted(conn, 200, content)
          _ -> send_resp(conn, 400, "")
        end
      end
      """,
      :get, "/b200")
  end

  test "get with basic 201 success response" do

    codesynth_match(
      %{"operationId" => "b201",
      "responses" => %{"201" => %{"description" => "resource created"}}},
      """
      get "/b201" do
        case TestModule.Web.Endpoint.b201(conn) do
          # handles resource created.
          {:ok, 201, details} -> send_formatted(conn, 201, %{"201" => "resource created: " <> details})
          {:ok, content} -> send_formatted(conn, 200, content)
          _ -> send_resp(conn, 400, "")
        end
      end
      """,
      :get, "/b201")
  end

  test "get with complex 404 error response" do

    codesynth_match(
    %{"operationId" => "e404",
      "responses" => %{"404" => %{"content" =>
                                  %{"application/json" =>
                                    %{"schema" =>
                                      %{"$ref" => "#/components/schemas/Pet"}}},
                                  "description" => "can't find the file"}}},
    """
    get "/e404" do
      case TestModule.Web.Endpoint.e404(conn) do
        # handles can't find the file.
        {:error, 404, details} ->
          send_formatted(conn, 404, %{"404" => "can't find the file: " <> details})

        {:ok, content} ->
          send_formatted(conn, 200, content)

        _ ->
          send_resp(conn, 400, "")
      end
    end
    """,
    :get, "/e404")
  end

  ##############################################################################
  ## parameters testing

  test "get_with_one_parameter" do
    codesynth_match(
      %{"operationId" => "oneparam",
      "parameters" => [%{"name" => "param1", "in" => "header", "required" => true}],
      "responses" => %{"default" => "success"}},
      """
      get "/oneparam" do
        with {:ok, param1} <- header_parameter(conn, "param1", :required) do
          case TestModule.Web.Endpoint.oneparam(conn, param1) do
            _ -> send_formatted(conn, 200, "success")
          end
        else
          {:error, problem} -> send_formatted(conn, 422, %{"422" => "error: \#{problem}"})
        end
      end
      """,
      :get, "/oneparam")
  end

  test "get_with_one_path_parameter" do
    codesynth_match(
      %{"operationId" => "oneparam",
      "parameters" => [%{"name" => "param1", "in" => "path", "required" => true}],
      "responses" => %{"default" => "success"}},
      """
      get "/oneparam/:param1" do
        case TestModule.Web.Endpoint.oneparam(conn, param1) do
          _ -> send_formatted(conn, 200, "success")
        end
      end
      """,
      :get, "/oneparam/{param1}")
  end

  test "get_with_one_query_parameter" do
    codesynth_match(
      %{"operationId" => "oneparam",
      "parameters" => [%{"name" => "param1", "in" => "query", "required" => true}],
      "responses" => %{"default" => "success"}},
      """
      get "/oneparam" do
        with {:ok, param1} <- query_parameter(conn, "param1", :required) do
          case TestModule.Web.Endpoint.oneparam(conn, param1) do
            _ -> send_formatted(conn, 200, "success")
          end
        else
          {:error, problem} -> send_formatted(conn, 422, %{"422" => "error: \#{problem}"})
        end
      end
      """,
      :get, "/oneparam")
  end

  test "get_with_path_and_query_parameter" do
    codesynth_match(
      %{"operationId" => "mixparam",
      "parameters" => [%{"name" => "param1", "in" => "path", "required" => true},
                       %{"name" => "param2", "in" => "query", "required" => true}],
      "responses" => %{"default" => "success"}},
      """
      get "/mixparam/:param1" do
        with {:ok, param2} <- query_parameter(conn, "param2", :required) do
          case TestModule.Web.Endpoint.mixparam(conn, param1, param2) do
            _ -> send_formatted(conn, 200, "success")
          end
        else
          {:error, problem} -> send_formatted(conn, 422, %{"422" => "error: \#{problem}"})
        end
      end
      """,
      :get, "/mixparam/{param1}")
  end

  test "get_with_two_parameters" do
    codesynth_match(
      %{"operationId" => "twoparam",
        "parameters" => [%{"name" => "param1", "in" => "header", "required" => true},
                         %{"name" => "param2", "in" => "header", "required" => true}],
        "responses" => %{"default" => "success"}},
      """
      get "/twoparam" do
        with {:ok, param1} <- header_parameter(conn, "param1", :required),
             {:ok, param2} <- header_parameter(conn, "param2", :required)
        do
          case TestModule.Web.Endpoint.twoparam(conn, param1, param2) do
            _ -> send_formatted(conn, 200, "success")
          end
        else
          {:error, problem} -> send_formatted(conn, 422, %{"422" => "error: \#{problem}"})
        end
      end
      """,
      :get, "/twoparam")
  end

  test "get_with_one_optional_parameter" do
    codesynth_match(
      %{"operationId" => "optparam",
        "parameters" => [%{"name" => "param1", "in" => "header"}],
        "responses" => %{"default" => "success"}},
      """
      get "/optparam" do
        param1 = header_parameter(conn, "param1")

        case TestModule.Web.Endpoint.optparam(conn, drop_nil_values(%{"param1" => param1})) do
          _ -> send_formatted(conn, 200, "success")
        end
      end
      """,
      :get, "/optparam")
  end

  test "get_with_two_optional_parameters" do
    codesynth_match(
    %{"operationId" => "twoparam",
      "parameters" => [%{"name" => "param1", "in" => "header"},
                       %{"name" => "param2", "in" => "header"}],
      "responses" => %{"default" => "success"}},
    """
    get "/twoparam" do
      param1 = header_parameter(conn, "param1")
      param2 = header_parameter(conn, "param2")

      case TestModule.Web.Endpoint.twoparam(conn, drop_nil_values(%{"param1" => param1, "param2" => param2})) do
        _ -> send_formatted(conn, 200, "success")
      end
    end
    """,
    :get, "/twoparam")
  end

  test "get_with_mixed_parameters" do
    codesynth_match(
    %{"operationId" => "mixparam",
      "parameters" => [%{"name" => "param1", "in" => "header", "required" => true},
                       %{"name" => "param2", "in" => "header"}],
      "responses" => %{"default" => "success"}},
    """
    get "/mixparam" do
      with {:ok, param1} <- header_parameter(conn, "param1", :required)
      do
        param2 = header_parameter(conn, "param2")

        case TestModule.Web.Endpoint.mixparam(conn, param1, drop_nil_values(%{"param2" => param2})) do
          _ -> send_formatted(conn, 200, "success")
        end
      else
        {:error, problem} -> send_formatted(conn, 422, %{"422" => "error: \#{problem}"})
      end
    end
    """,
    :get, "/mixparam")
  end

end


defmodule ExaggeratePetshopCodesynthTest do
  import Codesynth.Helper
  use ExUnit.Case

  test "pet shop get code gets generated" do
    codesynth_match(
      %{"description" => "",
        "operationId" => "logoutUser",
        "parameters" => [],
        "produces" => ["application/xml", "application/json"],
        "responses" => %{"default" => %{"description" => "successful operation"}},
        "summary" => "Logs out current logged in user session",
        "tags" => ["user"]},
      """
      get "/user/logout" do
        # Logs out current logged in user session

        case TestModule.Web.Endpoint.logoutUser(conn) do
          _ -> send_formatted(conn, 200, %{"description" => "successful operation"})
        end
      end
      """,
      :get, "/user/logout")
  end
end
