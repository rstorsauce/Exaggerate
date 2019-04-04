defmodule ExaggerateTest.Updater.RoutesTest do
  use ExUnit.Case

  @moduletag :updater

  @updated_routes """
  {
    "openapi": "3.0",
    "info": {
      "title": "api",
      "version": "0.1.0"
    },
    "consumes": [
      "application/json"
    ],
    "basePath": "/",
    "produces": [
      "application/json"
    ],
    "schemes": [
      "http", "https"
    ],
    "paths": {
      "/foo": {
        "get": {
          "operationId": "foo",
          "description": "does the foo thing",
          "responses": {
            "500": {"description": "server error"}
          }
        }
      },
      "/bar": {
        "get": {
          "operationId": "bar",
          "description": "does the bar thing",
          "responses": {
            "500": {"description": "server error"}
          }
        }
      }
    }
  }
  """

  @starting_code """
  defmodule Test.TestApiWeb.Router do
    use Plug.Router

    # this is going to be moved.

    alias Exaggerate.Tools

    alias Exaggerate.Responses

    # this is not.

    plug :match

    plug Plug.Parsers, parsers: [:urlencoded, :json, :multipart], pass: ["*/*"], json_decoder: Jason

    plug :dispatch

    # nor is this.

    @endpoint Test.TestWeb.Endpoint
    @validator Test.TestWeb.Validator

    # or this.

    get "/foo" do
      with {:ok, response} <- @endpoint.foo(conn) do
        #this is gone
        Responses.send_formatted(conn, 200, response)
      else
        {:ok, code, response} ->
          Responses.send_formatted(conn, code, response)

        {:error, ecode, response} ->
          Responses.send_formatted(conn, ecode, response)
      end

      # this is gone.
    end

    # this stays though

    match(_) do
      send_resp(conn, 404, "")
    end
  end

  # and this.
  """

  @finishing_code """
  defmodule Test.TestWeb.Router do
    use Plug.Router

    alias Exaggerate.Tools
    alias Exaggerate.Responses

    # this is going to be moved.

    # this is not.

    plug :match

    plug Plug.Parsers, parsers: [:urlencoded, :json, :multipart], pass: ["*/*"], json_decoder: Jason

    plug :dispatch

    # nor is this.

    @endpoint Test.TestWeb.Endpoint
    @validator Test.TestWeb.Validator

    # or this.

    get "/bar" do
      with {:ok, response} <- @endpoint.bar(conn) do
        Responses.send_formatted(conn, 200, response)
      else
        {:ok, code, response} ->
          Responses.send_formatted(conn, code, response)

        {:error, ecode, response} ->
          Responses.send_formatted(conn, ecode, response)
      end
    end

    get "/foo" do
      with {:ok, response} <- @endpoint.foo(conn) do
        Responses.send_formatted(conn, 200, response)
      else
        {:ok, code, response} ->
          Responses.send_formatted(conn, code, response)

        {:error, ecode, response} ->
          Responses.send_formatted(conn, ecode, response)
      end
    end

    # this stays though

    match(_) do
      send_resp(conn, 404, "")
    end
  end

  # and this.
  """

  describe "code analysis components work as expected" do

    @preamble """

    # this is going to be moved.



    # this is not.

    plug :match

    plug Plug.Parsers, parsers: [:urlencoded, :json, :multipart], pass: ["*/*"], json_decoder: Jason

    plug :dispatch

    # nor is this.

    @endpoint Test.TestWeb.Endpoint
    @validator Test.TestWeb.Validator

    # or this.
    """

    test "preamble" do
      assert @preamble == Exaggerate.Updater.preamble(@starting_code)
    end

    @postamble """

    # this stays though

    match(_) do
    send_resp(conn, 404, "")
    end
    end

    # and this.
    """

    test "postamble" do
      assert @postamble == Exaggerate.Updater.postamble(@starting_code)
    end

    @routes """
    get "/bar" do
      with {:ok, response} <- @endpoint.bar(conn) do
        Responses.send_formatted(conn, 200, response)
      else
        {:ok, code, response} ->
          Responses.send_formatted(conn, code, response)

        {:error, ecode, response} ->
          Responses.send_formatted(conn, ecode, response)
      end
    end

    get "/foo" do
      with {:ok, response} <- @endpoint.foo(conn) do
        Responses.send_formatted(conn, 200, response)
      else
        {:ok, code, response} ->
          Responses.send_formatted(conn, code, response)

        {:error, ecode, response} ->
          Responses.send_formatted(conn, ecode, response)
      end
    end
    """

    test "routes" do
      assert @routes == Exaggerate.Updater.routes(@updated_routes)
    end
  end

  test "an empty routes file is correctly updated" do
    assert @finishing_code == Exaggerate.Updater.update_router(Test.TestWeb, @starting_code, @updated_routes)
  end

end
