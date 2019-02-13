defmodule ExaggerateTest.Validator.ResponseTest do
  use ExUnit.Case

  alias Exaggerate.Validator
  alias Exaggerate.AST

  @basic_route """
  {
    "operationId": "root",
    "description": "gets by integer id",
    "responses": {
      "200": {
        "description": "pet response",
        "content": {
          "application/json": {
            "schema": {
              "type":"object",
              "properties":{
                "foo":{"type": "string"}
              }
            }
          }
        }
      }
    }
  }
  """

  describe "basic response filter" do
    @tag :one
    test "correctly creates a response macro" do
      router_res = """
      if Mix.env() in [:dev, :test] do
        defschema root_response_200_0: \"""
                  {
                    "properties": {
                      "foo": {
                        "type": "string"
                      }
                    },
                    "type": "object"
                  }
                  \"""
      end
      """

      assert router_res == {"/test", :post}
      |> Validator.route(Jason.decode!(@basic_route))
      |> AST.to_string
    end
  end
end
