defmodule ExaggerateTest.Validator.RequestBodyTest do
  use ExUnit.Case

  alias Exaggerate.AST
  alias Exaggerate.Validator

  # REQUEST BODY tests - as defined in the
  # OpenAPI documentation file:
  # https://swagger.io/docs/specification/describing-request-body/

  describe "really trivial requestbody " do
    test "single content route" do
      router_res = """
      defschema do_a_thing_body_0: "true"
      """

      assert router_res == {"/test", :post}
      |> Validator.route(
        %{"operationId" => "do_a_thing",
          "summary" => "post a thing",
          "requestBody" => %{
            "required" => true,
            "description" => """
            here's what goes in the body.
            """,
            "content" => %{
              "application/json" => %{"schema" => true}
        }}})
      |> AST.to_string
    end

    test "multiple content route" do
      router_res = """
      defschema do_a_thing_body_0: "true"

      defschema do_a_thing_body_1: \"""
                {
                  "type": "object"
                }
                \"""
      """

      assert router_res == {"/test", :post}
      |> Validator.route(
        %{"operationId" => "do_a_thing",
          "summary" => "post a thing",
          "requestBody" => %{
            "required" => true,
            "description" => """
            here's what goes in the body.
            """,
            "content" => %{
              "application/json" => %{"schema" => true},
              "multipart/form-data" => %{"schema" => %{"type" => "object"}}
        }}})
      |> AST.to_string
    end
  end
end
