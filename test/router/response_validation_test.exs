defmodule ExaggerateTest.Router.ResponseValidationTest do
  use ExUnit.Case

  alias Exaggerate.Router
  alias Exaggerate.AST

  describe "testing tested-endpoint generating defs" do
    test "simplest router" do
      blockcode_res = """
      get "/test" do
        with {:ok, response} <- @endpoint.test_endpoint(conn),
             :ok <- @validator.test_endpoint_response(response) do
          Responses.send_formatted(conn, 200, response)
        else
          {:error, ecode, response} ->
            Responses.send_formatted(conn, ecode, response)
        end
      end
      """

      route_descriptor = """
      {
        "operationId":"test_endpoint",
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
      """ |> Jason.decode!

      assert blockcode_res == {"/test", :get}
      |> Router.route(route_descriptor)
      |> AST.to_string
    end

  end

end
