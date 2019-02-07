defmodule ExaggerateTest.Validator.ParameterTest do
  use ExUnit.Case

  alias Exaggerate.Validator
  alias Exaggerate.AST

  # PARAMETERS tests - as defined in the
  # OpenAPI documentation file:
  # https://swagger.io/docs/specification/describing-parameters/

  describe "path parameters" do
    test "with a schema" do
      path_validation_res = """
      defparam :user_endpoint_parameters_0

      defschema user_endpoint_parameters_0: \"""
                {
                  "type": "integer"
                }
                \"""
      """

      assert path_validation_res == {"/users/{userId}", :get}
      |> Validator.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get a user by ID",
          "parameters" => [
            %{"in" => "path",
              "name" => "userId",
              "required" => true,
              "description" => "Numeric ID of the user to get",
              "schema" => %{"type" => "integer"}
            }]})
      |> AST.to_string
    end
  end

  # TODO:
  #   fill out more tests here.
end
