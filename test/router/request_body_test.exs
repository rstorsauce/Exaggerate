defmodule ExaggerateTest.Router.RequestBodyTest do
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
        with {:ok, content_type} <- Tools.match_mimetype(conn, ["application/json"]),
             {:ok, content} <- Tools.get_body(conn),
             :ok <- @validator.do_a_thing_content_0(content, content_type, "application/json"),
             {:ok, response} <- @endpoint.do_a_thing(conn, content) do
          send_formatted(conn, 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(conn, ecode, response)
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
               Tools.match_mimetype(conn, ["application/json", "application/x-www-form-urlencoded"]),
             {:ok, content} <- Tools.get_body(conn),
             :ok <- @validator.do_another_thing_content_0(content, content_type, "application/json"),
             :ok <-
               @validator.do_another_thing_content_1(
                 content,
                 content_type,
                 "application/x-www-form-urlencoded"
               ),
             {:ok, response} <- @endpoint.do_another_thing(conn, content) do
          send_formatted(conn, 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(conn, ecode, response)
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
