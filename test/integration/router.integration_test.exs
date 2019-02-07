defmodule ExaggerateTest.Router.IntegrationTest do

  use ExUnit.Case
  import Exaggerate

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @modules [:BasicWeb, :PathparamUuidWeb, :PathparamIdWeb, :QueryparamWeb,
            :QueryintparamWeb, :HeaderparamWeb, :BodyparamWeb]
  @ports Enum.take_random(2000..15000, 50)
  @portmapper Enum.into(Enum.zip(@modules, @ports), %{})

  def child_def(module, port) do
    router = Module.concat([__MODULE__, module, :Router])
    Cowboy.child_spec(scheme: :http, plug: router, options: [port: port])
  end

  setup_all do
    children = for m <- @modules, do: child_def(m, @portmapper[m])
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
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:BasicWeb]}/")
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
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:PathparamUuidWeb]}/uuid/#{@random_uuid}")
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
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:PathparamIdWeb]}/id/#{@random_number}")
      assert resp.status_code == 200
      assert resp.body == "received #{@random_number}"
    end

    test "sending a non-number 400s" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:PathparamIdWeb]}/id/#{@random_uuid}")
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
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:QueryparamWeb]}/?id=foo")
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
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:QueryintparamWeb]}/?id=123")
      assert resp.status_code == 200
      assert resp.body == "received 123"
    end

    test "non-integer 400's" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:QueryintparamWeb]}/?id=foo")
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
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:HeaderparamWeb]}/",
        [{"X-My-Header", "foo"}])
      assert resp.status_code == 200
      assert resp.body == "received foo"
    end
    test "missing case" do
      resp = HTTPoison.get!("http://localhost:#{@portmapper[:HeaderparamWeb]}/",
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
      resp = HTTPoison.post!("http://localhost:#{@portmapper[:BodyparamWeb]}/",
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

  # make a dummy validator that doesn't actually validate.
  defmodule BodyparamWeb.Validator do
    def root_content_0(_, _, _), do: :ok
  end

  #TODO: test cookie parameters.
end
