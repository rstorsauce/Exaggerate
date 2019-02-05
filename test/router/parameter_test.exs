defmodule ExaggerateTest.ParameterTest do
  use ExUnit.Case

  @moduletag :one

  alias Exaggerate.Router
  alias Exaggerate.AST

  # PARAMETERS tests - as defined in the
  # OpenAPI documentation file:
  # https://swagger.io/docs/specification/describing-parameters/

  describe "testing router path parameter" do

    test "simplest router with schema" do
      path_param_res = """
      get "/users/:user_id" do
        user_endpoint(conn, user_id)
      end
      """

      assert path_param_res == {"/users/{userId}", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get a user by ID",
          "parameters" => [
            %{"in" => "path",
              "name" => "userId",
              "required" => "true",
              "description" => "Numeric ID of the user to get"
            }]})
      |> AST.to_string
    end

    test "simplest router with schema type" do
      path_param_res = """
      get "/users/:user_id" do
        with <- Integer.parse(user_id) do
        user_endpoint(conn, user_id)
      end
      """

      assert path_param_res == {"/users/{userId}", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get a user by ID",
          "parameters" => [
            %{"in" => "path",
              "name" => "userId",
              "schema" => %{"type" => "integer"},
              "required" => "true",
              "description" => "Numeric ID of the user to get"
            }]})
      |> AST.to_string
    end
  end
end
