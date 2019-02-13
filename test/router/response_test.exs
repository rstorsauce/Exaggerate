defmodule ExaggerateTest.Router.ResponseTest do
  use ExUnit.Case

  alias Exaggerate.Router
  alias Exaggerate.AST

  # RESPONSES tests - as defined in the
  # OpenAPI documentation file:
  # https://swagger.io/docs/specification/describing-responses/

  describe "responses can be encoded" do
    test "simplest router" do
      blockcode_res = """
      put "/test" do
        with {:ok, response} <- @endpoint.test_endpoint(conn) do
          Responses.send_formatted(conn, 201, response)
        else
          {:error, ecode, response} ->
            Responses.send_formatted(conn, ecode, response)
        end
      end
      """

      assert blockcode_res == {"/test", :put}
      |> Router.route(%{"operationId" => "test_endpoint",
                        "responses" => %{"201" =>
                        %{"description" => "successful put"}}})
      |> AST.to_string
    end

    test "multiple responses" do
      blockcode_res = """
      put "/test" do
        with {:ok, code, response} <- @endpoint.test_endpoint(conn) do
          Responses.send_formatted(conn, code, response)
        else
          {:error, ecode, response} ->
            Responses.send_formatted(conn, ecode, response)
        end
      end
      """

      assert blockcode_res == {"/test", :put}
      |> Router.route(%{"operationId" => "test_endpoint",
                        "responses" =>
                        %{"201" => %{"description" => "successful put"},
                          "200" => %{"description" => "generic OK"}}})
      |> AST.to_string
    end

    test "range responses" do
      blockcode_res = """
      put "/test" do
        with {:ok, code, response} <- @endpoint.test_endpoint(conn) do
          Responses.send_formatted(conn, code, response)
        else
          {:error, ecode, response} ->
            Responses.send_formatted(conn, ecode, response)
        end
      end
      """

      assert blockcode_res == {"/test", :put}
      |> Router.route(%{"operationId" => "test_endpoint",
                        "responses" =>
                        %{"2XX" => %{"description" => "mysterious OK"}}})
      |> AST.to_string
    end
  end
end
