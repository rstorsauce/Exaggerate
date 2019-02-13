defmodule ExaggerateTest.Validation.Schemata do
  defmacro in_path do
    """
    {
      "paths": {
        "/{id}": {
          "get": {
            "operationId": "by_id",
            "description": "gets by integer id",
            "parameters": [
              {"in": "path",
               "name": "id",
               "required": true,
               "schema": {"type": "integer", "minimum": 1}}
            ]
          }
        }
      }
    }
    """
  end

  defmacro in_query do
    """
    {
      "paths": {
        "/": {
          "get": {
            "operationId": "for_foo",
            "description": "pings back foo string",
            "parameters": [
              {"in": "query",
               "name": "foo",
               "required": true,
               "schema": {"type": "string", "minLength": 2, "maxLength": 4}}
            ]
          }
        }
      }
    }
    """
  end

  defmacro in_query_optional do
    """
    {
      "paths": {
        "/": {
          "get": {
            "operationId": "for_foo",
            "description": "pings back foo string",
            "parameters": [
              {"in": "query",
               "name": "foo",
               "required": false,
               "schema": {"type": "string", "minLength": 2, "maxLength": 4}}
            ]
          }
        }
      }
    }
    """
  end

  defmacro in_body do
    """
    {
      "paths": {
        "/": {
          "post": {
            "operationId": "body_test",
            "description": "pings back foo string",
            "requestBody": {
              "description": "anything in an array, really",
              "required": true,
              "content": {
                "application/json": {
                  "schema": {
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 3
                  }
                }
              }
            }
          }
        }
      }
    }
    """
  end

  defmacro in_body_double do
    """
    {
      "paths": {
        "/": {
          "post": {
            "operationId": "body_test",
            "description": "pings back foo string",
            "requestBody": {
              "description": "anything in an array, really",
              "required": true,
              "content": {
                "application/json": {
                  "schema": {
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 3
                  }
                },
                "application/x-www-form-urlencoded": {
                  "schema": {
                    "type": "object",
                    "properties":{
                      "foo":{
                        "type": "string",
                        "minLength": 2,
                        "maxLength": 3
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """
  end

end

defmodule ExaggerateTest.Validation.IntegrationTest do

  use ExUnit.Case, async: true
  import Exaggerate

  #alias and require our repository of Schemata
  alias ExaggerateTest.Validation.Schemata
  require Schemata

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @modules [:InPathWeb, :InQueryWeb, :InQueryOptionalWeb, :InBodyWeb, :InBodyDoubleWeb]
  @ports Enum.take_random(2000..15000, 50)
  @portmapper Enum.into(Enum.zip(@modules, @ports), %{})

  def child_def(module, port) do
    router = Module.concat([__MODULE__, module, :Router])
    Cowboy.child_spec(scheme: :http, plug: router, options: [port: port])
  end

  setup_all do
    children = for m <- @modules, do: child_def(m, @portmapper[m])
    opts = [strategy: :one_for_one, name: Cowboy.Supervisor2]
    Supervisor.start_link(children, opts)
    :ok
  end

  router "in_path", Schemata.in_path
  validator "in_path", Schemata.in_path

  defmodule InPathWeb.Endpoint do
    def by_id(_conn, value) when is_integer(value) do
      {:ok, "received #{value}"}
    end
  end

  describe "schema validation in-path for integers" do
    test "validator works as expected" do
      refute :ok == InPathWeb.Validator.by_id_parameters_0(0)
      assert :ok == InPathWeb.Validator.by_id_parameters_0(10)
    end

    test "positive control" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InPathWeb]}/20")
      assert resp.status_code == 200
      assert resp.body == "received 20"
    end

    test "bad number results in failure code" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InPathWeb]}/0")
      assert resp.status_code == 400
    end
  end

  router "in_query", Schemata.in_query
  validator "in_query", Schemata.in_query

  defmodule InQueryWeb.Endpoint do
    def for_foo(_conn, value) do
      {:ok, "received #{value}"}
    end
  end

  describe "schema validation in-query for strings" do
    test "validator works as expected" do
      refute :ok == InQueryWeb.Validator.for_foo_parameters_0("")
      assert :ok == InQueryWeb.Validator.for_foo_parameters_0("cool")
      refute :ok == InQueryWeb.Validator.for_foo_parameters_0("way too long")
    end
    test "positive control" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryWeb]}/?foo=cool")
      assert resp.status_code == 200
      assert resp.body == "received cool"
    end
    test "nonexistent" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryWeb]}/?bar=baz")
      assert resp.status_code == 400
    end
    test "too short string" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryWeb]}/?foo=")
      assert resp.status_code == 400
    end
    test "too long string" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryWeb]}/?foo=bababooey")
      assert resp.status_code == 400
    end
  end

  router "in_query_optional", Schemata.in_query_optional
  validator "in_query_optional", Schemata.in_query_optional

  defmodule InQueryOptionalWeb.Endpoint do
    def for_foo(conn) do
      foo_val = conn.query_params["foo"]
      {:ok, "received #{inspect foo_val}"}
    end
  end

  describe "optional schema validation in-query for strings" do
    test "positive control" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryOptionalWeb]}/?foo=cool")
      assert resp.status_code == 200
      assert resp.body == "received \"cool\""
    end
    test "nonexistent" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryOptionalWeb]}/?bar=baz")
      assert resp.status_code == 200
      assert resp.body == "received nil"
    end
    test "too short string" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryOptionalWeb]}/?foo=")
      assert resp.status_code == 400
    end
    test "too long string" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryOptionalWeb]}/?foo=bababooey")
      assert resp.status_code == 400
    end
  end

  router "in_body", Schemata.in_body
  validator "in_body", Schemata.in_body

  defmodule InBodyWeb.Endpoint do
    def body_test(_conn, value) do
      {:ok, "received #{inspect value}"}
    end
  end

  describe "schema validation in-body for arrays" do
    test "validator works as expected" do
      refute :ok == InBodyWeb.Validator.body_test_content_0([])
      assert :ok == InBodyWeb.Validator.body_test_content_0([1,2,3])
      refute :ok == InBodyWeb.Validator.body_test_content_0([1,2,3,4,5])
    end

    test "bad content-type fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyWeb]}/",
        "[]")
      assert resp.status_code == 400
    end

    test "too short array fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyWeb]}/",
        "[]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 400
    end

    test "goldilocks array ok" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyWeb]}/",
        "[1, 2, 3]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 200
      assert resp.body == "received [1, 2, 3]"
    end

    test "too long array fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyWeb]}/",
        "[1, 2, 3, 4, 5]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 400
    end
  end

  router "in_body_double", Schemata.in_body_double
  validator "in_body_double", Schemata.in_body_double

  defmodule InBodyDoubleWeb.Endpoint do
    def body_test(_conn, value) do
      {:ok, "received #{inspect value}"}
    end
  end

  describe "schema validation in-body for double definition" do
    test "first body test works as expected" do
      refute :ok == InBodyDoubleWeb.Validator.body_test_content_0([])
      assert :ok == InBodyDoubleWeb.Validator.body_test_content_0([1,2,3])
      refute :ok == InBodyDoubleWeb.Validator.body_test_content_0([1,2,3,4,5])
    end

    test "too short array fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyDoubleWeb]}/",
        "[]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 400
    end

    test "goldilocks array ok" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyDoubleWeb]}/",
        "[1, 2, 3]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 200
      assert resp.body == "received [1, 2, 3]"
    end

    test "too long array fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyDoubleWeb]}/",
        "[1, 2, 3, 4, 5]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 400
    end

    test "second body test works as expected" do
      refute :ok == InBodyDoubleWeb.Validator.body_test_content_1(%{"foo" => ""})
      assert :ok == InBodyDoubleWeb.Validator.body_test_content_1(%{"foo" => "abc"})
      refute :ok == InBodyDoubleWeb.Validator.body_test_content_1(%{"foo" => "abcdef"})
    end

    test "too short string fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyDoubleWeb]}/",
        "foo=", [{"Content-Type", "application/x-www-form-urlencoded"}])
      assert resp.status_code == 400
    end

    test "goldilocks string ok" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyDoubleWeb]}/",
        "foo=bar", [{"Content-Type", "application/x-www-form-urlencoded"}])
      assert resp.status_code == 200
      assert resp.body == "received %{\"foo\" => \"bar\"}"
    end

    test "too long string fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyDoubleWeb]}/",
        "foo=bababooey", [{"Content-Type", "application/x-www-form-urlencoded"}])
      assert resp.status_code == 400
    end

  end
end
