defmodule ExaggerateTest.RequestBodyTest do
  use ExUnit.Case

  alias Exaggerate.AST
  alias Exaggerate.Router

  # REQUEST BODY tests - as defined in the
  # OpenAPI documentation file:
  # https://swagger.io/docs/specification/describing-request-body/

  describe "basic requestbody request" do
    test "single content route" do
      router_res = """
      post "/test" do
        # post a thing
        with {:ok, content_type} <- Process.requestbody_content(var!(conn), ["application/json"]),
             :ok <- Validation.do_a_thing_content(var!(conn).body_params, content_type),
             {:ok, response} <- Endpoint.do_a_thing(var!(conn), content) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert router_res == {"/test", :post}
      |> Router.route(
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

    test "multi content route looks almost identical" do
      router_res = """
      post "/test" do
        # post a thing
        with {:ok, content_type} <-
               Process.requestbody_content(var!(conn), [
                 "application/json",
                 "application/x-www-form-urlencoded"
               ]),
             :ok <- Validation.do_another_thing_content(var!(conn).body_params, content_type),
             {:ok, response} <- Endpoint.do_another_thing(var!(conn), content) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert router_res == {"/test", :post}
      |> Router.route(
        %{"operationId" => "do_another_thing",
          "summary" => "post a thing",
          "requestBody" => %{
            "required" => true,
            "description" => """
            here's what goes in the body.
            """,
            "content" => %{
              "application/json" => %{"schema" => true},
              "application/x-www-form-urlencoded" => %{"schema" => true}
        }}})
      |> AST.to_string
    end
  end

end
