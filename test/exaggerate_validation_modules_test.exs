defmodule Validation.Helper do
  defmacro __using__(_args) do
    quote do
      import Validation.Helper
      require Jason
    end
  end

  defmacro passes(module, code) do
    quote do
      assert Module.concat(Exaggerate.Validation, unquote(module)).validate(unquote(code)) == :ok
    end
  end

  defmacro fails(module, code) do
    quote do
      {v1, v2, v3} = Module.concat(Exaggerate.Validation, unquote(module)).validate(unquote(code))
      assert v1 == :error
    end
  end
end

defmodule ExaggerateInfoUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @infobase """
  {
  "title": "Sample Pet Store App",
  "description": "This is a sample server for a pet store.",
  "termsOfService": "http://example.com/terms/",
  "contact": {
    "name": "API Support",
    "url": "http://www.example.com/support",
    "email": "support@example.com"
  },
  "license": {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  },
  "version": "1.0.1"
  }
  """ |> Jason.decode!

  test "sample info passes" do
    passes Info, @infobase
  end

  test "sample info without required data fails" do
    fails Info, @infobase |> Map.delete("title")
    fails Info, @infobase |> Map.delete("version")
  end

  test "sample info with optional data passes" do
    passes Info, @infobase |> Map.delete("description")
    passes Info, @infobase |> Map.delete("termsOfService")
    passes Info, @infobase |> Map.delete("contact")
    passes Info, @infobase |> Map.delete("license")
  end

  test "sample info with scrambled type fails" do
    fails Info, @infobase |> Map.put("title", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("version", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("description", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("termsOfService", %{"this is not" => "a string"})
    fails Info, @infobase |> Map.put("contact", "this is not an object")
    fails Info, @infobase |> Map.put("license", %{"this is not" => "a license object"})
    fails Info, @infobase |> Map.put("license", "this is not an object")
  end
end


defmodule ExaggerateContactUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @contactbase """
  {
    "name": "API Support",
    "url": "http://www.example.com/support",
    "email": "support@example.com"
  }
  """ |> Jason.decode!

  test "sample contact passes" do
    passes Contact, @contactbase
  end

  test "sample contact with optional data passes" do
    passes Contact, @contactbase |> Map.delete("name")
    passes Contact, @contactbase |> Map.delete("url")
    passes Contact, @contactbase |> Map.delete("email")
  end

  test "sample contact with scrambled type fails" do
    fails Contact, @contactbase |> Map.put("name", %{"this is not" => "a string"})
    fails Contact, @contactbase |> Map.put("url", "this is not an url")
    fails Contact, @contactbase |> Map.put("email", "this is not an email")
  end
end

defmodule ExaggerateLicenseUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @licensebase """
  {
    "name": "Apache 2.0",
    "url": "https://www.apache.org/licenses/LICENSE-2.0.html"
  }
  """ |> Jason.decode!

  test "sample license passes" do
    passes License, @licensebase
  end

  test "sample license without required data fails" do
    fails License, @licensebase |> Map.delete("name")
  end

  test "sample license with optional data passes" do
    passes License, @licensebase |> Map.delete("url")
  end

  test "sample license with scrambled type fails" do
    fails License, @licensebase |> Map.put("name", %{"this is not" => "a string"})
    fails License, @licensebase |> Map.put("url", "this is not an url")
  end
end

defmodule ExaggerateServerUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @basicserverbase """
  {
    "url": "https://development.gigantic-server.com/v1",
    "description": "Development server"
  }
  """ |> Jason.decode!

  test "sample basic server passes" do
    passes Server, @basicserverbase
  end

  test "sample basic server without required data fails" do
    fails Server, @basicserverbase |> Map.delete("url")
  end

  test "sample basic server with optional data passes" do
    passes Server, @basicserverbase |> Map.delete("description")
  end

  test "sample basic server with scrambled type fails" do
    fails Server, @basicserverbase |> Map.put("url", "this is not an url")
    fails Server, @basicserverbase |> Map.put("description", %{"this is not" => "a string"})
  end

  @variableserverbase """
  {
    "url": "https://{username}.gigantic-server.com:{port}/{basePath}",
    "description": "The production API server",
    "variables": {
      "username": {
        "default": "demo",
        "description": "this value is assigned by the service provider, in this example `gigantic-server.com`"
      },
      "port": {
        "enum": [
          "8443",
          "443"
        ],
        "default": "8443"
      },
      "basePath": {
        "default": "v2"
      }
    }
  }
  """ |> Jason.decode!

  test "sample variable server passes" do
    passes Server, @variableserverbase
  end

  test "sample variable server with wonky variable fails" do
    fails Server, @variableserverbase |> Map.put("variables", %{"this is not" => "a server variable"})
  end
end


defmodule ExaggerateServerVariableUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @servervariablebase """
  {
    "default": "demo",
    "description": "this value is assigned by the service provider, in this example `gigantic-server.com`"
  }
  """ |> Jason.decode!

  test "sample servervariable passes" do
    passes ServerVariable, @servervariablebase
  end

  test "sample servervariable without required data fails" do
    fails ServerVariable, @servervariablebase |> Map.delete("default")
  end

  test "sample servervariable with optional data passes" do
    passes ServerVariable, @servervariablebase |> Map.delete("description")
  end

  test "sample servervariable with scrambled type fails" do
    fails ServerVariable, @servervariablebase |> Map.put("default", %{"this is not" => "a string"})
    fails ServerVariable, @servervariablebase |> Map.put("description", %{"this is not" => "a string"})
  end
end

defmodule ExaggerateOperationUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @operationbase """
  {
    "tags": [
      "pet"
    ],
    "summary": "Updates a pet in the store with form data",
    "operationId": "updatePetWithForm",
    "parameters": [
      {
        "name": "petId",
        "in": "path",
        "description": "ID of pet that needs to be updated",
        "required": true,
        "schema": {
          "type": "string"
        }
      }
    ],
    "requestBody": {
      "content": {
        "application/x-www-form-urlencoded": {
          "schema": {
            "type": "object",
             "properties": {
                "name": {
                  "description": "Updated name of the pet",
                  "type": "string"
                },
                "status": {
                  "description": "Updated status of the pet",
                  "type": "string"
               }
             },
          "required": ["status"]
          }
        }
      }
    },
    "responses": {
      "200": {
        "description": "Pet updated.",
        "content": {
          "application/json": {},
          "application/xml": {}
        }
      },
      "405": {
        "description": "Invalid input",
        "content": {
          "application/json": {},
          "application/xml": {}
        }
      }
    },
    "security": [
      {
        "petstore_auth": [
          "write:pets",
          "read:pets"
        ]
      }
    ]
  }
  """ |> Jason.decode!


  test "sample operation passes" do
    passes Operation, @operationbase
  end

  test "sample operation without required data fails" do
    fails Operation, @operationbase |> Map.delete("responses")
    fails Operation, @operationbase |> Map.delete("operationId") #note this is required by exaggerate
  end

  test "sample operation with optional data passes" do
    passes Operation, @operationbase |> Map.delete("tags")
    passes Operation, @operationbase |> Map.delete("summary")
    passes Operation, @operationbase |> Map.delete("parameters")
    passes Operation, @operationbase |> Map.delete("requestBody")
    passes Operation, @operationbase |> Map.delete("security")
  end

  test "sample operation with scrambled type fails" do
    fails Operation, @operationbase |> Map.put("responses",   %{"this is not" => "a responses map"})
    fails Operation, @operationbase |> Map.put("responses",   "this is not a map")
    fails Operation, @operationbase |> Map.put("operationId", %{"this is not" => "a string"})
    fails Operation, @operationbase |> Map.put("tags",        "this is not a tags array")
    fails Operation, @operationbase |> Map.put("summary",     %{"this is not" => "a string"})
    fails Operation, @operationbase |> Map.put("responses",   [%{"this is not" => "a parameter array"}])
    fails Operation, @operationbase |> Map.put("responses",   "this is not an array")
    fails Operation, @operationbase |> Map.put("requestBody", %{"this is not" => "a requestbody object"})
    fails Operation, @operationbase |> Map.put("requestBody", "this is not an object")
    fails Operation, @operationbase |> Map.put("security",    %{"this is not" => "a security object"})
    fails Operation, @operationbase |> Map.put("security",    "this is not an object")
  end
end

defmodule ExaggerateExternalDocUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @externaldocbase """
  {
    "description": "Find more info here",
    "url": "https://example.com"
  }
  """ |> Jason.decode!


  test "sample externaldoc passes" do
    passes Externaldocumentation, @externaldocbase
  end

  test "sample externaldoc without required data fails" do
    fails Externaldocumentation, @externaldocbase |> Map.delete("url")
  end

  test "sample externaldoc with optional data passes" do
    passes Externaldocumentation, @externaldocbase |> Map.delete("description")
  end

  test "sample externaldoc with scrambled type fails" do
    fails Externaldocumentation, @externaldocbase |> Map.put("description",   %{"this is not" => "a string"})
    fails Externaldocumentation, @externaldocbase |> Map.put("url", %{"this is not" => "a url"})
  end
end

defmodule ExaggerateParamUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @integerheaderparambase """
  {
    "name": "token",
    "in": "header",
    "description": "token to be passed as a header",
    "required": true,
    "schema": {
      "type": "array",
      "items": {
        "type": "integer",
        "format": "int64"
      }
    },
    "style": "simple"
  }
  """ |> Jason.decode!


  test "sample header parameter passes" do
    passes Parameter, @integerheaderparambase
  end

  test "sample header parameter without required data fails" do
    fails Parameter, @integerheaderparambase |> Map.delete("name")
    fails Parameter, @integerheaderparambase |> Map.delete("in")
  end

  test "sample header parameter with optional data passes" do
    passes Parameter, @integerheaderparambase |> Map.delete("description")
    passes Parameter, @integerheaderparambase |> Map.delete("required")
    passes Parameter, @integerheaderparambase |> Map.delete("schema")
    passes Parameter, @integerheaderparambase |> Map.delete("style")
  end

  test "sample header parameter with scrambled types fails" do
    fails Parameter, @integerheaderparambase |> Map.put("name", %{"this is not" => "a string"})
    fails Parameter, @integerheaderparambase |> Map.put("in", %{"this is not" => "a string"})
    fails Parameter, @integerheaderparambase |> Map.put("in", "qux")  #must be in the magic collection of values.
    fails Parameter, @integerheaderparambase |> Map.put("description", %{"this is not" => "a string"})
    fails Parameter, @integerheaderparambase |> Map.put("required", "this is not a boolean")
    fails Parameter, @integerheaderparambase |> Map.put("schema", "this is not an object")
    fails Parameter, @integerheaderparambase |> Map.put("schema", %{"this is not" => "a schema object"})
  end

  @stringpathparambase """
  {
    "name": "username",
    "in": "path",
    "description": "username to fetch",
    "required": true,
    "schema": {
      "type": "string"
    }
  }
  """ |> Jason.decode!

  test "sample path parameter passes" do
    passes Parameter, @stringpathparambase
  end

  test "sample path parameter without required data fails" do
    fails Parameter, @stringpathparambase |> Map.delete("name")
    fails Parameter, @stringpathparambase |> Map.delete("in")
    fails Parameter, @stringpathparambase |> Map.delete("required")
    fails Parameter, @stringpathparambase |> Map.put("required", false)
  end

  test "sample path parameter with optional data passes" do
    passes Parameter, @stringpathparambase |> Map.delete("description")
    passes Parameter, @stringpathparambase |> Map.delete("schema")
  end
end


defmodule ExaggerateRequestBodyUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @requestbodybase """
  {
    "description": "user to add to the system",
    "content": {
      "application/json": {
        "schema": {
          "$ref": "#/components/schemas/User"
        },
        "examples": {
            "user" : {
              "summary": "User Example",
              "externalValue": "http://foo.bar/examples/user-example.json"
            }
          }
      },
      "application/xml": {
        "schema": {
          "$ref": "#/components/schemas/User"
        },
        "examples": {
            "user" : {
              "summary": "User example in XML",
              "externalValue": "http://foo.bar/examples/user-example.xml"
            }
          }
      },
      "text/plain": {
        "examples": {
          "user" : {
              "summary": "User example in Plain text",
              "externalValue": "http://foo.bar/examples/user-example.txt"
          }
        }
      },
      "*/*": {
        "examples": {
          "user" : {
              "summary": "User example in other format",
              "externalValue": "http://foo.bar/examples/user-example.whatever"
          }
        }
      }
    }
  }
  """ |> Jason.decode!


  test "sample request body parameter passes" do
    passes Requestbody, @requestbodybase
  end

  test "sample request body parameter without required data fails" do
    fails Requestbody, @requestbodybase |> Map.delete("content")
  end

  test "sample request body parameter with optional data passes" do
    passes Requestbody, @requestbodybase |> Map.delete("description")
  end

  test "sample request body parameter with scrambled types fails" do
    fails Requestbody, @requestbodybase |> Map.put("content", "this is not a content object")
    fails Requestbody, @requestbodybase |> Map.put("content", %{"this is not" => "a content object"})
    fails Requestbody, @requestbodybase |> Map.put("description", %{"this is not" => "a string"})
  end

end

defmodule ExaggerateMediatypeUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @mediatypebase """
  {
    "application/json": {
      "schema": {
           "$ref": "#/components/schemas/Pet"
      },
      "examples": {
        "cat" : {
          "summary": "An example of a cat",
          "value":
            {
              "name": "Fluffy",
              "petType": "Cat",
              "color": "White",
              "gender": "male",
              "breed": "Persian"
            }
        },
        "dog": {
          "summary": "An example of a dog with a cat's name",
          "value" :  {
            "name": "Puma",
            "petType": "Dog",
            "color": "Black",
            "gender": "Female",
            "breed": "Mixed"
          },
        "frog": {
            "$ref": "#/components/examples/frog-example"
          }
        }
      }
    }
  }
  """ |> Jason.decode!


  test "sample mediatype parameter passes" do
    passes Mediatype, @mediatypebase
  end

  test "sample mediatype parameter with optional data passes" do
    passes Mediatype, @mediatypebase |> Map.delete("schema")
    passes Mediatype, @mediatypebase |> Map.delete("examples")
  end

  test "sample mediatype parameter with scrambled types fails" do
    fails Mediatype, @mediatypebase |> Map.put("schema", %{"this is" => "not a schema object"})
    fails Mediatype, @mediatypebase |> Map.put("schema", "this is not an object")
    fails Mediatype, @mediatypebase |> Map.put("examples", "this is not an array")
    fails Mediatype, @mediatypebase |> Map.put("examples", [%{"this is not" => "an array of examples"}])
  end

end

defmodule ExaggerateEncodingUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @encodingbase """
  {
    "contentType": "image/png, image/jpeg",
    "headers": {
      "X-Rate-Limit-Limit": {
        "description": "The number of allowed requests in the current period",
        "schema": {
          "type": "integer"
        }
      }
    }
  }
  """ |> Jason.decode!


  test "sample encoding parameter passes" do
    passes Encoding, @encodingbase
  end

  test "sample encoding parameter with optional data passes" do
    passes Encoding, @encodingbase |> Map.delete("contentType")
    passes Encoding, @encodingbase |> Map.delete("headers")
  end

  test "sample encoding parameter with scrambled types fails" do
    fails Encoding, @encodingbase |> Map.put("contentType", %{"this is" => "not a string"})
    fails Encoding, @encodingbase |> Map.put("contentType", "this is not a content-type list")
    fails Encoding, @encodingbase |> Map.put("headers", %{"this is" => "not a headers object"})
    fails Encoding, @encodingbase |> Map.put("headers", "this is not an object")
  end
end

defmodule ExaggerateResponsesUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @responsesbase """
  {
    "200": {
      "description": "a pet to be returned",
      "content": {
        "application/json": {
          "schema": {
            "$ref": "#/components/schemas/Pet"
          }
        }
      }
    },
    "default": {
      "description": "Unexpected error",
      "content": {
        "application/json": {
          "schema": {
            "$ref": "#/components/schemas/ErrorModel"
          }
        }
      }
    }
  }
  """ |> Jason.decode!


  test "sample responses parameter passes" do
    passes Responses, @responsesbase
  end

  test "sample responses parameter with bad key" do
    resampled_parameter = @responsesbase["200"]
    fails Responses, @responsesbase |> Map.put("foo", resampled_parameter)
  end
end

defmodule ExaggerateResponseUnitTest do
  use Validation.Helper
  use ExUnit.Case

  @responsebase """
  {
    "description": "A simple string response",
    "content": {
      "text/plain": {
        "schema": {
          "type": "string"
        }
      }
    },
    "headers": {
      "X-Rate-Limit-Limit": {
        "description": "The number of allowed requests in the current period",
        "schema": {
          "type": "integer"
        }
      },
      "X-Rate-Limit-Remaining": {
        "description": "The number of remaining requests in the current period",
        "schema": {
          "type": "integer"
        }
      },
      "X-Rate-Limit-Reset": {
        "description": "The number of seconds left in the current period",
        "schema": {
          "type": "integer"
        }
      }
    }
  }
  """ |> Jason.decode!


  test "sample response parameter passes" do
    passes Response, @responsebase
  end

  test "sample response parameter without required data fails" do
    fails Response, @responsebase |> Map.delete("description")
  end

  test "sample response parameter with optional data passes" do
    passes Response, @responsebase |> Map.delete("content")
    passes Response, @responsebase |> Map.delete("headers")
  end

  test "sample response parameter with scrambled types fails" do
    fails Response, @responsebase |> Map.put("description", %{"this is " => "not a string"})
    fails Response, @responsebase |> Map.put("content", "this is not an object")
    fails Response, @responsebase |> Map.put("content", %{"this is" => "not a content object"})
    fails Response, @responsebase |> Map.put("headers", "this is not an object")
    fails Response, @responsebase |> Map.put("headers", %{"this is" => "not a headers object"})
  end

end
