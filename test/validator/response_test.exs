defmodule ExaggerateTest.Validator.ResponseTest do
  use ExUnit.Case

  alias Exaggerate.Validator
  alias Exaggerate.AST

  @blank_route """
  {
    "operationId": "root",
    "description": "gets by integer id",
    "responses": {
      "200": {"description": "pet response"}
    }
  }
  """
  describe "blank response filter" do
    test "correctly creates no response macro" do
      assert {:__block__, [], [nil]} == {"/test", :post}
      |> Validator.route(Jason.decode!(@blank_route))
    end
  end


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
    test "correctly creates a response macro" do
      router_res = """
      if Mix.env() in [:dev, :test] do
        def root_response({:ok, resp}) do
          with :ok <- root_response({:ok, 200, resp}) do
            {:ok, resp}
          end
        end

        def root_response({:ok, 200, resp}) do
          with :ok <- root_response_200_0(resp) do
            {:ok, 200, resp}
          end
        end

        def root_response(any) do
          any
        end

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
      else
        def root_response(any) do
          any
        end
      end
      """

      assert router_res == {"/test", :post}
      |> Validator.route(Jason.decode!(@basic_route))
      |> AST.to_string
    end
  end

  @alt_code_route """
  {
    "operationId": "root",
    "description": "gets by integer id",
    "responses": {
      "201": {
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

  describe "response filter with alternative response code" do
    test "correctly creates a response macro" do
      router_res = """
      if Mix.env() in [:dev, :test] do
        def root_response({:ok, resp}) do
          with :ok <- root_response({:ok, 201, resp}) do
            {:ok, resp}
          end
        end

        def root_response({:ok, 201, resp}) do
          with :ok <- root_response_201_0(resp) do
            {:ok, 201, resp}
          end
        end

        def root_response(any) do
          any
        end

        defschema root_response_201_0: \"""
                  {
                    "properties": {
                      "foo": {
                        "type": "string"
                      }
                    },
                    "type": "object"
                  }
                  \"""
      else
        def root_response(any) do
          any
        end
      end
      """

      assert router_res == {"/test", :post}
      |> Validator.route(Jason.decode!(@alt_code_route))
      |> AST.to_string
    end
  end


  @error_type_route """
  {
    "operationId": "root",
    "description": "gets by integer id",
    "responses": {
      "200": {"description": "pet response"},
      "400": {
        "description": "oops",
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

  describe "response filter with single error response type" do
    test "correctly creates a response macro" do
      router_res = """
      if Mix.env() in [:dev, :test] do
        def root_response({:error, 400, resp}) do
          with :ok <- root_response_400_0(resp) do
            {:error, 400, resp}
          end
        end

        def root_response(any) do
          any
        end

        defschema root_response_400_0: \"""
                  {
                    "properties": {
                      "foo": {
                        "type": "string"
                      }
                    },
                    "type": "object"
                  }
                  \"""
      else
        def root_response(any) do
          any
        end
      end
      """

      assert router_res == {"/test", :post}
      |> Validator.route(Jason.decode!(@error_type_route))
      |> AST.to_string
    end
  end

  @multi_type_route """
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
          },
          "image/jpeg": {
            "schema": true
          }
        }
      }
    }
  }
  """

  describe "response filter with multiple response type" do
    test "correctly creates a response macro" do
      router_res = """
      if Mix.env() in [:dev, :test] do
        def root_response({:ok, resp}) do
          with :ok <- root_response({:ok, 200, resp}) do
            {:ok, resp}
          end
        end

        def root_response({:ok, 200, resp}) do
          resp
          |> case do
            {:file, path} ->
              {MIME.from_path(path), File.read!(resp)}

            _ ->
              {"application/json", resp}
          end
          |> case do
            {"application/json", value} ->
              root_response_200_0(value)

            {"image/jpeg", value} ->
              root_response_200_1(value)
          end
          |> case do
            :ok ->
              {:ok, 200, resp}

            any ->
              any
          end
        end

        def root_response(any) do
          any
        end

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

        defschema root_response_200_1: "true"
      else
        def root_response(any) do
          any
        end
      end
      """

      assert router_res == {"/test", :post}
      |> Validator.route(Jason.decode!(@multi_type_route))
      |> AST.to_string
    end
  end
end
