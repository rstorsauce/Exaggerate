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
      @spec do_a_thing_content_0(Exonerate.json(), String.t(), String.t()) :: :ok | Exaggerate.error()
      def do_a_thing_content_0(content, "application/json", "application/json") do
        do_a_thing_content_0(content)
      end

      def do_a_thing_content_0(_, _, _) do
        :ok
      end

      defschema do_a_thing_content_0: "true"
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
      @spec do_a_thing_content_0(Exonerate.json(), String.t(), String.t()) :: :ok | Exaggerate.error()
      def do_a_thing_content_0(content, "application/json", "application/json") do
        do_a_thing_content_0(content)
      end

      def do_a_thing_content_0(_, _, _) do
        :ok
      end

      defschema do_a_thing_content_0: "true"

      @spec do_a_thing_content_1(Exonerate.json(), String.t(), String.t()) :: :ok | Exaggerate.error()
      def do_a_thing_content_1(content, "multipart/form-data", "multipart/form-data") do
        do_a_thing_content_1(content)
      end

      def do_a_thing_content_1(_, _, _) do
        :ok
      end

      defschema do_a_thing_content_1: \"""
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
