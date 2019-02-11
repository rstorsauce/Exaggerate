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
end

defmodule ExaggerateTest.Validation.IntegrationTest do

  use ExUnit.Case #, async: true
  import Exaggerate

  #alias and require our repository of Schemata
  alias ExaggerateTest.Validation.Schemata
  require Schemata

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @modules [:InPathWeb, :InQueryWeb, :InBodyWeb]
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
    test "too short string" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryWeb]}/?foo=")
      assert resp.status_code == 400
    end
    test "too long string" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:InQueryWeb]}/?foo=bababooey")
      assert resp.status_code == 400
    end
  end

  router "in_body", Schemata.in_body
  validator "in_body", Schemata.in_body

  defmodule InBodyWeb.Endpoint do
    def body_test(_conn, value) do
      {:ok, "received #{value}"}
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

    @tag :one
    test "too short array fails" do
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:InBodyWeb]}/",
        "[]", [{"Content-Type", "application/json"}])
      assert resp.status_code == 400
    end
  end

end
