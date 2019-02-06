defmodule ExaggerateTest.ParameterTest do
  use ExUnit.Case

  alias Exaggerate.Router
  alias Exaggerate.AST

  # PARAMETERS tests - as defined in the
  # OpenAPI documentation file:
  # https://swagger.io/docs/specification/describing-parameters/

  describe "path parameters" do
    test "simplest router with schema" do
      path_param_res = """
      get "/users/:user_id" do
        # Get a user by ID
        with {:ok, user_id} <- Tools.get_path(var!(conn), "user_id"),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), user_id) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert path_param_res == {"/users/{userId}", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get a user by ID",
          "parameters" => [
            %{"in" => "path",
              "name" => "userId",
              "required" => true,
              "description" => "Numeric ID of the user to get"
            }]})
      |> AST.to_string
    end

    test "router with integer schema type" do
      path_param_res = """
      get "/users/:user_id" do
        # Get a user by ID
        with {:ok, user_id} <- Tools.get_path(var!(conn), "user_id", :integer),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), user_id) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
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
              "required" => true,
              "description" => "Numeric ID of the user to get"
            }]})
      |> AST.to_string
    end

    test "router with multiple matches" do
      path_param_res = """
      get "/cars/:car_id/drivers/:driver_id" do
        # Get car and driver ids
        with {:ok, car_id} <- Tools.get_path(var!(conn), "car_id"),
             {:ok, driver_id} <- Tools.get_path(var!(conn), "driver_id"),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), car_id, driver_id) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert path_param_res == {"/cars/{carId}/drivers/{driverId}", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get car and driver ids",
          "parameters" => [
            %{"in" => "path",
              "name" => "carId",
              "required" => true,
              "description" => "Numeric ID of the user to get"
            },
            %{"in" => "path",
              "name" => "driverId",
              "required" => true,
              "description" => "Numeric ID of the user to get"
            }]})
      |> AST.to_string
    end
  end

  describe "query parameters" do
    test "simple path parameter with schema" do
      query_param_res = """
      get "/pets/findByStatus" do
        # Get pet status
        with {:ok, status} <- Tools.get_query(var!(conn), "status"),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), status) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert query_param_res == {"/pets/findByStatus", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get pet status",
          "parameters" => [
            %{"in" => "query",
              "name" => "status",
              "required" => true
            }]})
      |> AST.to_string
    end

    test "simple path parameter with multiple parameters" do
      query_param_res = """
      get "/notes" do
        # Get pet status
        with {:ok, offset} <- Tools.get_query(var!(conn), "offset", :integer),
             {:ok, limit} <- Tools.get_query(var!(conn), "limit", :integer),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), offset, limit) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert query_param_res == {"/notes", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Get pet status",
          "parameters" => [
            %{"in" => "query",
              "name" => "offset",
              "schema" => %{"type" => "integer"},
              "required" => true,
              "description" => "The number of items to skip before starting to collect the result set"
            },
            %{"in" => "query",
              "name" => "limit",
              "schema" => %{"type" => "integer"},
              "required" => true,
              "description" => "The numbers of items to return"
            }]})
      |> AST.to_string
    end
  end

  describe "header parameters" do
    @tag :one
    test "simple parameter with schema" do
      query_param_res = """
      get "/ping" do
        # Checks if the server is alive
        with {:ok, x_request_id} <- Tools.get_header(var!(conn), "X-Request-ID", :string),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), x_request_id) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert query_param_res == {"/ping", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Checks if the server is alive",
          "parameters" => [
            %{"in" => "header",
              "name" => "X-Request-ID",
              "schema" => %{"type" => "string"},
              "required" => true
            }]})
      |> AST.to_string
    end
  end

  describe "cookie parameters" do
    test "simple parameter with schema" do
      query_param_res = """
      get "/ping" do
        # Uses cookie things
        with {:ok, debug} <- Tools.get_cookie(var!(conn), "debug", :integer),
             {:ok, csrftoken} <- Tools.get_cookie(var!(conn), "csrftoken", :string),
             {:ok, response} <- Endpoint.user_endpoint(var!(conn), debug, csrftoken) do
          send_formatted(var!(conn), 200, response)
        else
          {:error, ecode, response} ->
            send_formatted(var!(conn), ecode, response)
        end
      end
      """

      assert query_param_res == {"/ping", :get}
      |> Router.route(
        %{"operationId" => "user_endpoint",
          "summary" => "Uses cookie things",
          "parameters" => [
            %{"in" => "cookie",
              "name" => "debug",
              "schema" => %{"type" => "integer",
                            "enum" => [0, 1],
                            "default" => 0},
              "required" => true
            },
            %{"in" => "cookie",
              "name" => "csrftoken",
              "schema" => %{"type" => "string"},
              "required" => true
            }]})
      |> AST.to_string
    end
  end

  # TODO:
  #   serialization
  #   reserved characters (allowReserved parameter)
end
