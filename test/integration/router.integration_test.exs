defmodule ExaggerateTest.Router.IntegrationTest do

  use ExUnit.Case
  import Exaggerate

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @basic_port          Enum.random(2000..2050)
  @pathparam_uuid_port Enum.random(2051..2100)
  @pathparam_id_port   Enum.random(2101..2150)
  @queryparam_port     Enum.random(2151..2200)
  @queryintparam_port  Enum.random(2201..2250)
  @headerparam_port    Enum.random(2251..2300)
  @bodyparam_port      Enum.random(2301..2350)

  def child_def(module, port) do
    router = Module.concat([__MODULE__, module, :Router])
    Cowboy.child_spec(scheme: :http, plug: router, options: [port: port])
  end

  setup_all do
    children = [
      child_def(BasicWeb, @basic_port),
      child_def(PathparamUuidWeb, @pathparam_uuid_port),
      child_def(PathparamIdWeb, @pathparam_id_port),
      child_def(QueryparamWeb, @queryparam_port),
      child_def(QueryintparamWeb, @queryintparam_port),
      child_def(HeaderparamWeb, @headerparam_port),
      child_def(BodyparamWeb, @bodyparam_port)
    ]

    opts = [strategy: :one_for_one, name: Cowboy.Supervisor]
    Supervisor.start_link(children, opts)
    :ok
  end

  # for these tests we won't supply a "full" OpenAPI schema.
  router "basic", """
  {
    "paths": {
      "/": {
        "get": {
          "operationId": "root",
          "description": "gets root directory"
        }
      }
    }
  }
  """

  defmodule BasicWeb.Endpoint do
    def root(_conn) do
      {:ok, "received"}
    end
  end

  describe "pinging the basic module" do
    test "can get a response from root" do
      resp = HTTPoison.get!("http://localhost:#{@basic_port}/")
      assert resp.status_code == 200
      assert resp.body == "received"
    end
  end

  router "pathparam_uuid", """
  {
    "paths": {
      "/uuid/{uuid}": {
        "get": {
          "operationId": "uuid",
          "description": "gets by uuid",
          "parameters": [{"in": "path", "name": "uuid", "required": true}]
        }
      }
    }
  }
  """

  defmodule PathparamUuidWeb.Endpoint do
    def uuid(_conn, uuid) do
      {:ok, "received #{uuid}"}
    end
  end

  @random_uuid ([?a..?z, ?A..?Z, ?0..?9]
               |> Enum.concat()
               |> Enum.take_random(16)
               |> List.to_string)

  describe "pinging the uuid module" do
    test "can get a correct response" do
      resp = HTTPoison.get!("http://localhost:#{@pathparam_uuid_port}/uuid/#{@random_uuid}")
      assert resp.status_code == 200
      assert resp.body == "received #{@random_uuid}"
    end
  end

  router "pathparam_id", """
  {
    "paths": {
      "/id/{id}": {
        "get": {
          "operationId": "id",
          "description": "gets by id",
          "parameters": [{"in": "path", "name": "id", "required": true,
                          "schema": {"type": "integer"}}]
        }
      }
    }
  }
  """

  defmodule PathparamIdWeb.Endpoint do
    def id(_conn, id) when is_integer(id) do
      {:ok, "received #{id}"}
    end
  end

  @random_number Enum.random(0..1000)

  describe "sending numerical id in path" do
    test "can do this in path" do
      resp = HTTPoison.get!("http://localhost:#{@pathparam_id_port}/id/#{@random_number}")
      assert resp.status_code == 200
      assert resp.body == "received #{@random_number}"
    end

    test "sending a non-number 400s" do
      resp = HTTPoison.get!("http://localhost:#{@pathparam_id_port}/id/#{@random_uuid}")
      assert resp.status_code == 400
    end
  end

  router "queryparam", """
  {
    "paths": {
      "/": {
        "get": {
          "operationId": "root",
          "description": "gets by id",
          "parameters": [{"in": "query", "name": "id", "required": true}]
        }
      }
    }
  }
  """

  defmodule QueryparamWeb.Endpoint do
    def root(_conn, id) do
      {:ok, "received #{id}"}
    end
  end

  describe "a query with a string parameter" do
    test "can do this in query param" do
      resp = HTTPoison.get!("http://localhost:#{@queryparam_port}/?id=foo")
      assert resp.status_code == 200
      assert resp.body == "received foo"
    end
  end

  router "queryintparam", """
  {
    "paths": {
      "/": {
        "get": {
          "operationId": "root",
          "description": "gets by id",
          "parameters": [{"in": "query", "name": "id", "required": true,
                          "schema": {"type": "integer"}}]
        }
      }
    }
  }
  """

  defmodule QueryintparamWeb.Endpoint do
    def root(_conn, id) when is_integer(id) do
      {:ok, "received #{id}"}
    end
  end

  describe "a query with an integer parameter" do
    test "can do this in query param" do
      resp = HTTPoison.get!("http://localhost:#{@queryintparam_port}/?id=123")
      assert resp.status_code == 200
      assert resp.body == "received 123"
    end

    test "non-integer 400's" do
      resp = HTTPoison.get!("http://localhost:#{@queryintparam_port}/?id=foo")
      assert resp.status_code == 400
    end
  end

  router "headerparam", """
  {
    "paths": {
      "/": {
        "get": {
          "operationId": "root",
          "description": "gets by id",
          "parameters": [{"in": "header", "name": "X-My-Header", "required": true}]
        }
      }
    }
  }
  """

  defmodule HeaderparamWeb.Endpoint do
    def root(_conn, xmyheader) do
      {:ok, "received #{xmyheader}"}
    end
  end

  describe "headers can have params " do
    test "simple case" do
      resp = HTTPoison.get!("http://localhost:#{@headerparam_port}/",
        [{"X-My-Header", "foo"}])
      assert resp.status_code == 200
      assert resp.body == "received foo"
    end
    test "missing case" do
      resp = HTTPoison.get!("http://localhost:#{@headerparam_port}/",
        [{"X-Your-Header", "foo"}])
      assert resp.status_code == 400
    end
  end

  router "bodyparam", """
  {
    "paths": {
      "/": {
        "post": {
          "operationId": "root",
          "description": "gets by id",
          "requestBody": {"content":
            {"application/json": {"schema": true}}}
        }
      }
    }
  }
  """

  describe "body params can be matched " do
    test "in the simplest case" do
      resp = HTTPoison.post!("http://localhost:#{@bodyparam_port}/",
        "{\"foo\":\"bar\"}", [{"Content-Type", "application/json"}])
      assert resp.status_code == 200
      assert resp.body == "received {\"foo\":\"bar\"}"
    end
  end

  defmodule BodyparamWeb.Endpoint do
    def root(_conn, content) do
      {:ok, "received " <> Jason.encode!(content)}
    end
  end

  #TODO: test cookie parameters.
end
