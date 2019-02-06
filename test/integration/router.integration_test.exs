defmodule ExaggerateTest.Router.IntegrationTest do

  use ExUnit.Case

  import Exaggerate

  # we're going to stand up a server here.
  alias Plug.Adapters.Cowboy

  router "basic", """
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
      "http"
    ],
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

end
