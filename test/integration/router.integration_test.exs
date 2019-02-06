defmodule ExaggerateTest.Router.IntegrationTest do

  use ExUnit.Case
  import Exaggerate

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  @basic_port          Enum.random(2000..2050)
  @pathparam_uuid_port Enum.random(2051..2100)

  setup_all do
    children = [
      Cowboy.child_spec(scheme: :http,
                        plug: __MODULE__.BasicWeb.Router,
                        options: [port: @basic_port]),
      Cowboy.child_spec(scheme: :http,
                        plug: __MODULE__.PathparamUuidWeb.Router,
                        options: [port: @pathparam_uuid_port])
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
          "description": "gets root directory",
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
    test "can get a response from root" do
      resp = HTTPoison.get!("http://localhost:#{@pathparam_uuid_port}/uuid/#{@random_uuid}")
      assert resp.status_code == 200
      assert resp.body == "received #{@random_uuid}"
    end
  end

end
