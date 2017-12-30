defmodule Exaggerate.Validation.OpenAPI do

  use Exaggerate.Validation.Helpers

  validate_keys [:openapi, :info, :paths], [:servers, :components, :security, :tags, :externalDocs]

  version_parameter :openapi

  object_parameter :info
  object_parameter :paths
  array_parameter  :servers,      Server
  object_parameter :components
  array_parameter  :security,     Securityrequirement
  array_parameter  :tags,         Tag
  object_parameter :externalDocs, ExternalDocumentation

  def further_validation(%{"openapi" => "3.0" <> _b}), do: :ok
  def further_validation(%{}) do
    Logger.warn("openapi < 3.0 only partially supported")
    :ok
  end
end

defmodule Exaggerate.Validation.Info do

  use Exaggerate.Validation.Helpers

  validate_keys [:title, :version], [:description, :termsOfService, :contact, :license]

  string_parameter  :title
  version_parameter :version
  string_parameter  :description
  string_parameter  :termsOfService
  object_parameter  :contact
  object_parameter  :license
end

defmodule Exaggerate.Validation.Contact do

  use Exaggerate.Validation.Helpers

  validate_keys [], [:name, :url, :email]

  string_parameter :name
  url_parameter    :url
  email_parameter  :email
end

defmodule Exaggerate.Validation.License do

  use Exaggerate.Validation.Helpers

  validate_keys [:name], [:url]

  string_parameter :name
  url_parameter    :url
end

defmodule Exaggerate.Validation.Server do

  use Exaggerate.Validation.Helpers

  validate_keys [:url], [:description, :variables]

  url_parameter    :url
  string_parameter :description
  map_parameter    :variables,   ServerVariable
end

defmodule Exaggerate.Validation.ServerVariable do

  use Exaggerate.Validation.Helpers

  validate_keys [:default], [:enum, :description]

  sarray_parameter  :enum
  string_parameter  :default
  string_parameter  :description
end

defmodule Exaggerate.Validation.Components do

  use Exaggerate.Validation.Helpers

  validate_keys [], [:schemas, :responses, :parameters, :examples, :requestBodies, :headers, :securitySchemes, :links, :callbacks]

  map_parameter :schemas,         Schema,         Reference
  map_parameter :responses,       Response,       Reference
  map_parameter :parameters,      Parameter,      Reference
  map_parameter :examples,        Example,        Reference
  map_parameter :requestBodies,   Requestbody,    Reference
  map_parameter :headers,         Header,         Reference
  map_parameter :securitySchemes, Securityscheme, Reference
  map_parameter :links,           Link,           Reference
  map_parameter :callbacks,       Callback,       Reference

end

defmodule Exaggerate.Validation.Paths do
  def validate(paths = %{}) do
    paths |> Map.keys
      |> Enum.map(fn key ->
        #do some key value validation.
        Exaggerate.Validation.Pathitem.validate(paths[key])
      end)
      |> Exaggerate.Validation.error_search
  end
end

defmodule Exaggerate.Validation.Pathitem do

  use Exaggerate.Validation.Helpers

  validate_keys [],[:ref, :summary, :description, :get, :put, :post, :delete, :options, :head, :patch, :trace, :servers, :parameters]

  string_parameter :ref
  string_parameter :summary
  string_parameter :description

  object_parameter :get,     Operation
  object_parameter :put,     Operation
  object_parameter :post,    Operation
  object_parameter :delete,  Operation
  object_parameter :options, Operation
  object_parameter :head,    Operation
  object_parameter :patch,   Operation
  object_parameter :trace,   Operation

  array_parameter :servers,    Server
  array_parameter :parameters, Parameter, Reference

  def further_validation(%{"parameters" => params}) do
    duplicate_parameters = (params |> Enum.map(fn p -> p["name"] end) |> Exaggerate.Validation.duplicates)
    if duplicate_parameters do
      {:error, Operation, "parameters has duplicates: #{duplicate_parameters}"}
    else
      :ok
    end
  end
  def further_validation(%{}), do: :ok
end

defmodule Exaggerate.Validation.Operation do

  use Exaggerate.Validation.Helpers

  validate_keys [:operationId, :responses],[:tags, :summary, :description, :externalDocs, :parameters, :requestBody, :callbacks, :deprecated, :security, :servers]

  string_parameter   :operationId
  object_parameter   :responses
  sarray_parameter   :tags
  string_parameter   :summary
  string_parameter   :description
  object_parameter   :externalDocs, Externaldocumentation
  array_parameter    :parameters,   Parameter,   Reference
  object_parameter   :requestBody,  Requestbody, Reference
  map_parameter      :callbacks,    Callback,    Reference
  boolean_parameter  :deprecated
  array_parameter    :security,     Securityrequirement
  array_parameter    :servers,      Server

  #make sure that there are no duplicates going on.
  #TODO:  do a second-level parse of reference parameters.
  #TODO:  make sure responses meets the patterned definition

  def further_validation(%{"parameters" => params}) do
    duplicate_parameters = (params |> Enum.map(fn p -> p["name"] end) |> Exaggerate.Validation.duplicates)
    if duplicate_parameters do
      {:error, Operation, "parameters has duplicates: #{duplicate_parameters}"}
    else
      :ok
    end
  end
  def further_validation(%{}), do: :ok
end

defmodule Exaggerate.Validation.Externaldocumentation do

  use Exaggerate.Validation.Helpers

  validate_keys [:url], [:description]

  url_parameter    :url
  string_parameter :description
end

defmodule Exaggerate.Validation.Parameter do

  use Exaggerate.Validation.Helpers

  validate_keys [:name, :in],[:description, :required, :deprecated, :allowEmptyValue,
                                 :style, :explode, :allowReserved, :schema, :example, :examples,
                                 :content]

  string_parameter  :name
  string_parameter  :in
  string_parameter  :description
  boolean_parameter :required
  boolean_parameter :deprecated
  boolean_parameter :allowEmptyValue

  ##############################################################################
  # schema-style parameters

  string_parameter  :style
  boolean_parameter :explode
  boolean_parameter :allowReserved
  object_parameter  :schema
  any_parameter     :example
  array_parameter   :examples, Example

  ##############################################################################
  # content-style parameters

  map_parameter     :content, Mediatype

  ##############################################################################

  def further_validation(%{"schema" => _, "content" => _}), do: {:error, Parameter, "schema is mutually exclusive to content"}
  def further_validation(%{"examples" => _, "example" => _}), do: {:error, Parameter, "examples is mutually exclusive to example"}
  def further_validation(%{"in" => "path", "required" => true}), do: :ok
  def further_validation(%{"in" => "path"}), do: {:error, Parameter, "path parameters must be required"}
  def further_validation(%{"in" => location}) when location in ["query", "header", "path", "cookie"], do: :ok
  def further_validation(%{"in" => location}) when location in ["body", "formData"] do
    Logger.warn("Swagger/OpenAPI 2.0 parameter location #{inspect location} support is being deprecated.")
    :ok
  end
  def further_validation(%{"in" => location}), do: {:error, Parameter, "path parameter location #{inspect location} is not supported."}

end

defmodule Exaggerate.Validation.Requestbody do

  use Exaggerate.Validation.Helpers

  validate_keys [:content], [:description, :required]

  map_parameter     :content, Mediatype
  string_parameter  :description
  boolean_parameter :required
end

defmodule Exaggerate.Validation.Mediatype do

  use Exaggerate.Validation.Helpers

  validate_keys [], [:schema, :example, :examples, :encoding]

  object_parameter :schema,    Schema, Reference
  object_parameter :example,   Any
  map_parameter    :examples,  Example, Reference
  map_parameter    :encoding,  Encoding

  def further_validation(%{"example" => _, "examples" => _}), do: {:error, Mediatype, "examples is mutually exclusive to example"}
  def further_validation(%{}) do
    #TODO:  make sure that the encoding is in the schema.
    :ok
  end
end

defmodule Exaggerate.Validation.Encoding do

  use Exaggerate.Validation.Helpers

  validate_keys [],[:contentType, :headers, :style, :explode, :allowReserved]

  string_parameter  :contentType
  map_parameter     :headers, Header, Reference
  string_parameter  :style
  boolean_parameter :explode
  boolean_parameter :allowReserved

  def further_validation(%{"contentType" => typelist}) when is_binary(typelist) do
    typelist |> String.split(",")
             |> Enum.map(&String.trim/1)
             |> Enum.map(&Exaggerate.Validation.is_mimestring/1)
             |> Enum.reduce(:ok, fn (true, :ok) -> :ok
                                    (false, :ok) -> {:error, Encoding, "contentType value is not a mimestring"}
                                    (_, err) -> err
                                 end)
  end
  def further_validation(%{}), do: :ok
end

defmodule Exaggerate.Validation.Responses do

  def invalid_or_nil("default"), do: nil
  def invalid_or_nil("1" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("2" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("3" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("4" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("5" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil(anything_else), do: anything_else

  def validate(responses) when is_map(responses) do
    #check to make sure that the keys are all in the correct form (default or [1-5]xx)
    invalid_responses = responses |> Map.keys
        |> Enum.map(&Exaggerate.Validation.Responses.invalid_or_nil/1)
        |> Enum.reduce(false, &Kernel.||/2)

    if (invalid_responses) do
      {:error, Responses, "invalid response code found: #{invalid_responses}"}
    else
      responses |> Map.values
        |> Enum.map(&Exaggerate.Validation.Response.validate/1)
        |> Exaggerate.Validation.error_search
    end
  end
  def validate(responses), do: {:error, Responses, "not an object map, got #{inspect responses}"}
end

defmodule Exaggerate.Validation.Response do

  use Exaggerate.Validation.Helpers

  validate_keys [:description],[:headers, :content, :links]

  string_parameter :description
  map_parameter    :headers, Header,    Reference
  map_parameter    :content, Mediatype, Reference
  map_parameter    :links,   Link,      Reference
end

defmodule Exaggerate.Validation.Callback do
  def validate(callback = %{}) do
    callback |> Map.values
      |> Enum.map(&Exaggerate.Validation.Pathitem.validate/1)
      |> Exaggerate.Validation.error_search
  end
end

defmodule Exaggerate.Validation.Example do

  use Exaggerate.Validation.Helpers

  validate_keys [],[:summary, :description, :value, :externalValue]

  string_parameter :summary
  string_parameter :description
  object_parameter :value,      Any
  url_parameter    :externalValue

  def further_validation(%{"value" => _, "externalValue" => _}), do: {:error, Example, "value is exclusive to externalValue"}
  def further_validation(%{}), do: :ok
end

defmodule Exaggerate.Validation.Link do

  use Exaggerate.Validation.Helpers

  validate_keys [],[:operationRef, :operationId, :parameters, :requestBody, :description, :server]

  string_parameter :operationRef
  string_parameter :operationId
  map_parameter    :parameters,  Any, Runtimeexpression
  object_parameter :requestBody, Any, Runtimeexpression
  string_parameter :description
  object_parameter :server,      Server
end

defmodule Exaggerate.Validation.Header do

  use Exaggerate.Validation.Helpers

  validate_keys [], [:description, :required, :deprecated, :allowEmptyValue,
                        :style, :explode, :allowReserved, :schema, :example, :examples,
                        :content]

  string_parameter  :description
  boolean_parameter :required
  boolean_parameter :deprecated
  boolean_parameter :allowEmptyValue

  ##############################################################################
  # schema-style parameters

  string_parameter  :style
  boolean_parameter :explode
  boolean_parameter :allowReserved
  object_parameter  :schema
  any_parameter     :example
  array_parameter   :examples, Example

  ##############################################################################
  # content-style parameters

  map_parameter     :content, Mediatype

  ##############################################################################

  def further_validation(%{"schema" => _, "content" => _}), do: {:error, Header, "schema is mutually exclusive to content"}
  def further_validation(%{"examples" => _, "example" => _}), do: {:error, Header, "examples is mutually exclusive to example"}
  def further_validation(%{"in" => _}), do: {:error, Header, "headers may not have in parameters"}
  def further_validation(%{"name" => _}), do: {:error, Header, "headers may not have names"}
  def further_validation(%{}), do: :ok

end

defmodule Exaggerate.Validation.Tag do

  use Exaggerate.Validation.Helpers

  validate_keys [:name], [:description, :externalDocs]

  string_parameter :name
  string_parameter :description
  object_parameter :externalDocs, Externaldocumentation
end

defmodule Exaggerate.Validation.Examples do

  use Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Reference do

  use Exaggerate.Validation.Helpers

  def validate(%{"$ref" => _ref}), do: :ok
  def validate(map) when is_map(map), do: {:error, Reference, "invalid reference #{inspect map}."}
  def validate(not_map), do: {:error, Reference, "invalid reference, expected map, got #{inspect not_map}."}

end

defmodule Exaggerate.Validation.Runtimeexpression do

  use Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Schema do

  use Exaggerate.Validation.Helpers

  def validate(_), do: :ok
  #pass_validate()
end

defmodule Exaggerate.Validation.Discriminator do

  use Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.XML do

  use Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Securityscheme do

  require Logger

  use Exaggerate.Validation.Helpers

  validate_keys [:type], [:name, :in, :scheme, :bearerFormat, :flows, :openIdConnectUrl]

  string_parameter :type
  string_parameter :name
  string_parameter :in
  string_parameter :scheme
  string_parameter :bearerFormat
  object_parameter :flows
  url_parameter    :openIdConnectUrl

  def further_validation(%{"type" => "apiKey", "name" => _, "in" => "query"}),  do: :ok
  def further_validation(%{"type" => "apiKey", "name" => _, "in" => "header"}), do: :ok
  def further_validation(%{"type" => "apiKey", "name" => _, "in" => "cookie"}), do: :ok
  def further_validation(%{"type" => "apiKey", "name" => _, "in" => location}), do: {:error, Securityscheme, "apiKey security data cannot be in #{location}"}
  def further_validation(%{"type" => "apiKey", "in" => _}),                     do: {:error, Securityscheme, "apiKey security requires a name parameter."}
  def further_validation(%{"type" => "apiKey"}),                                do: {:error, Securityscheme, "apiKey security requires an in parameter."}

  def further_validation(%{"type" => "http", "scheme" => _scheme}) do
    #TODO: check HTTP RFC 7235 to correctly identify valid schemes.
    Logger.warn("http security schemes are currently not correctly parsed.")
    :ok
  end
  def further_validation(%{"type" => "http"}), do: {:error, Securityscheme, "http security requires an RFC7235 scheme"}

  def further_validation(%{"type" => "oauth2", "flows" => _}), do: :ok
  def further_validation(%{"type" => "oauth2"}), do: {:error, Securityscheme, "oauth2 security requires a flow object"}

  def further_validation(%{"type" => "openIdConnect", "openIdConnectUrl" => _}), do: :ok
  def further_validation(%{"type" => "openIdConnect"}), do: {:error, Securityscheme, "openIdConnect requires a connection URL"}

  def further_validation(%{}), do: {:error, Securityscheme, "there is an error in the type of your security scheme."}
end

defmodule Exaggerate.Validation.Flows do

  use Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Flow do

  use Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Securityrequirement do

  use Exaggerate.Validation.Helpers

  pass_validate()
end
