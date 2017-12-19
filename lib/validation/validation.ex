
defmodule Exaggerate.Validation do

  @doc """
    tests if an array has any duplicates, in which case, the first found one is reported.
    otherwise returns nil.

    # Examples

    iex> Exaggerate.Validation.duplicates([1,2,3,4])      #==>
    nil

    iex> Exaggerate.Validation.duplicates([1,2,2,3,4])    #==>
    2

    iex> Exaggerate.Validation.duplicates([1,2,3,4,4,2])  #==>
    2
  """
  def duplicates([head | tail]), do: duplicates(tail, tail, head)
  def duplicates([], _, _), do: nil
  def duplicates([statehead, statetail], [], _), do: duplicates(statetail, statetail, statehead)
  def duplicates(_state, [head | _tail], head), do: head
  def duplicates(state, [_head | tail], check), do: duplicates(state, tail, check)

  @doc """
    searches an array of error/ok responses and falls through if
    there's any error; but ok's if none are found.
  """
  def error_search([]), do: {:ok}
  def error_search([{:ok} | tail]), do: error_search(tail)
  def error_search([error | _tail]), do: error

  def validation_or({:ok}, _, _error), do: {:ok}
  def validation_or(_, {:ok}, _error), do: {:ok}
  def validation_or(_,_, error), do: error
end

defmodule Exaggerate.Validation.OpenAPI do

  import Exaggerate.Validation.Helpers

  validate_keys [:openapi, :info, :paths], [:servers, :components, :security, :tags, :externalDocs]

  version_parameter :openapi

  object_parameter :info
  object_parameter :paths
  array_parameter  :servers,      Server
  object_parameter :components
  array_parameter  :security,     SecurityRequirement
  array_parameter  :tags,         Tag
  object_parameter :externalDocs, ExternalDocumentation
end

defmodule Exaggerate.Validation.Info do

  import Exaggerate.Validation.Helpers

  validate_keys [:title, :version], [:description, :termsOfService, :contact, :license]

  string_parameter  :title
  version_parameter :version
  string_parameter  :description
  string_parameter  :termsOfService
  object_parameter  :contact
  string_parameter  :license
end

defmodule Exaggerate.Validation.Contact do

  import Exaggerate.Validation.Helpers

  validate_keys [], [:name, :url, :email]

  string_parameter :name
  url_parameter    :url
  email_parameter  :email
end

defmodule Exaggerate.Validation.License do

  import Exaggerate.Validation.Helpers

  validate_keys [:name], [:url]

  string_parameter :name
  url_parameter    :url
end

defmodule Exaggerate.Validation.Server do

  import Exaggerate.Validation.Helpers

  validate_keys [:url], [:description, :variables]

  url_parameter    :url
  string_parameter :description
  map_parameter    :variables,   ServerVariables
end

defmodule Exaggerate.Validation.ServerVariables do

  import Exaggerate.Validation.Helpers

  validate_keys [:url], [:enum, :default]

  url_parameter     :url
  sarray_parameter  :enum
  string_parameter  :default
end

defmodule Exaggerate.Validation.Components do

  import Exaggerate.Validation.Helpers

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
  def is_valid?(paths = %{}) do
    paths |> Map.keys
      |> Enum.map(fn key ->
        #do some key value validation.
        Exaggerate.Validation.Pathitem.is_valid?(paths[key])
      end)
  end
end

defmodule Exaggerate.Validation.Pathitem do

  import Exaggerate.Validation.Helpers

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
      {:ok}
    end
  end

end

defmodule Exaggerate.Validation.Operation do

  import Exaggerate.Validation.Helpers

  validate_keys [:operationId, :responses],[:tags, :summary, :description, :externalDocs, :parameters, :requestBody, :callbacks, :deprecated, :security, :servers]

  string_parameter   :operationId
  object_parameter   :responses
  sarray_parameter   :tags
  string_parameter   :summary
  string_parameter   :description
  object_parameter   :externalDocs, ExternalDocumentation
  array_parameter    :parameters,   Parameter,   Reference
  object_parameter   :requestBody,  Requestbody, Reference
  map_parameter      :callbacks,    Callback,    Reference
  boolean_parameter  :deprecated
  array_parameter    :security,     SecurityRequirement
  array_parameter    :servers,      Server

  #make sure that there are no duplicates going on.
  #TODO:  do a second-level parse of reference parameters.
  #TODO:  make sure responses meets the patterned definition

  def further_validation(%{"parameters" => params}) do
    duplicate_parameters = (params |> Enum.map(fn p -> p["name"] end) |> Exaggerate.Validation.duplicates)
    if duplicate_parameters do
      {:error, Operation, "parameters has duplicates: #{duplicate_parameters}"}
    else
      {:ok}
    end
  end
  def further_validation(%{}), do: {:ok}
end

defmodule Exaggerate.Validation.ExternalDocumentation do

  import Exaggerate.Validation.Helpers

  validate_keys [:url], [:description]

  url_parameter    :url
  string_parameter :description
end

defmodule Exaggerate.Validation.Parameter do

  import Exaggerate.Validation.Helpers

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

  map_parameter     :content, MediaType

  ##############################################################################

  def further_validation(%{"schema" => _, "content" => _}), do: {:error, Parameter, "schema is mutually exclusive to content"}
  def further_validation(%{"examples" => _, "example" => _}), do: {:error, Parameter, "examples is mutually exclusive to example"}
  def further_validation(%{"in" => "path", "required" => true}), do: {:ok}
  def further_validation(%{"in" => "path"}), do: {:error, Parameter, "path parameters must be required"}
  def further_validation(%{}), do: {:ok}

end

defmodule Exaggerate.Validation.Requestbody do

  import Exaggerate.Validation.Helpers

  validate_keys [:content], [:description, :required]

  map_parameter     :content, MediaType
  string_parameter  :description
  boolean_parameter :required
end

defmodule Exaggerate.Validation.Mediatype do

  import Exaggerate.Validation.Helpers

  validate_keys [], [:schema, :example, :examples, :encoding]

  object_parameter :schema,    Schema, Reference
  object_parameter :example,   Any
  array_parameter  :examples,  Example
  map_parameter    :encoding,  Encoding

  def further_validation(%{"example" => _, "examples" => _}), do: {:error, Mediatype, "examples is mutually exclusive to example"}
  def further_validation(%{}) do
    #TODO:  make sure that the encoding is in the schema.
    {:ok}
  end
end

defmodule Exaggerate.Validation.Encoding do

  import Exaggerate.Validation.Helpers

  validate_keys [],[:contentType, :headers, :style, :explode, :allowReserved]

  string_parameter  :contentType
  map_parameter     :headers, Header, Reference
  string_parameter  :style
  boolean_parameter :explode
  boolean_parameter :allowReserved
end

defmodule Exaggerate.Validation.Responses do

  def invalid_or_nil("default"), do: nil
  def invalid_or_nil("1" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("2" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("3" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("4" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil("5" <> <<_a::size(16)>>), do: nil
  def invalid_or_nil(anything_else), do: anything_else

  def is_valid?(responses = %{}) do
    #check to make sure that the keys are all in the correct form (default or [1-5]xx)
    invalid_responses = responses |> Map.keys
        |> Enum.map(&Exaggerate.Validation.Responses.invalid_or_nil/1)
        |> Enum.reduce(false, &Kernel.||/2)

    if (invalid_responses) do
      {:error, Responses, "invalid response code found: #{invalid_responses}"}
    else
      responses |> Map.values
        |> Enum.map(&Exaggerate.Validation.Response.is_valid?/1)
        |> Exaggerate.Validation.error_search
    end
  end
end

defmodule Exaggerate.Validation.Response do

  import Exaggerate.Validation.Helpers

  validate_keys [:description],[:headers, :content, :links]

  string_parameter :description
  map_parameter    :headers, Header,    Reference
  map_parameter    :content, MediaType, Reference
  map_parameter    :links,   Link,      Reference
end

defmodule Exaggerate.Validation.Callback do
  def is_valid?(callback = %{}) do
    callback |> Map.values
      |> Enum.map(&Exaggerate.Validation.Pathitem.is_valid?/1)
      |> Exaggerate.Validation.error_search
  end
end

defmodule Exaggerate.Validation.Example do

  import Exaggerate.Validation.Helpers

  validate_keys [],[:summary, :description, :value, :externalValue]

  string_parameter :summary
  string_parameter :description
  object_parameter :value,      Any
  url_parameter    :externalValue

  def further_validation(%{"value" => _, "externalValue" => _}), do: {:error, Example, "value is exclusive to externalValue"}
  def further_validation(%{}), do: {:ok}
end

defmodule Exaggerate.Validation.Link do

  import Exaggerate.Validation.Helpers

  validate_keys [],[:operationRef, :operationId, :parameters, :requestBody, :description, :server]

  string_parameter :operationRef
  string_parameter :operationId
  map_parameter    :parameters,  Any, RuntimeExpression
  object_parameter :requestBody, Any, RuntimeExpression
  string_parameter :description
  object_parameter :server,      Server
end

defmodule Exaggerate.Validation.Header do

  import Exaggerate.Validation.Helpers

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

  map_parameter     :content, MediaType

  ##############################################################################

  def further_validation(%{"schema" => _, "content" => _}), do: {:error, Header, "schema is mutually exclusive to content"}
  def further_validation(%{"examples" => _, "example" => _}), do: {:error, Header, "examples is mutually exclusive to example"}
  def further_validation(%{"in" => _}), do: {:error, Header, "headers may not have in parameters"}
  def further_validation(%{"name" => _}), do: {:error, Header, "heades may not have names"}
  def further_validation(%{}), do: {:ok}

end

defmodule Exaggerate.Validation.Tag do

  import Exaggerate.Validation.Helpers

  validate_keys [:name], [:description, :externalDocs]

  string_parameter :name
  string_parameter :description
  object_parameter :externalDocs, ExternalDocumentation
end

defmodule Exaggerate.Validation.Examples do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Reference do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.RuntimeExpression do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Schema do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Discriminator do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.XML do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.SecurityScheme do

  import Exaggerate.Validation.Helpers

  validate_keys [:type], [:name, :in, :scheme, :bearerFormat, :flows, :openIdConnectUrl]

  string_parameter :type
  string_parameter :name
  string_parameter :in
  string_parameter :scheme
  string_parameter :bearerFormat
  object_parameter :flows
  url_parameter    :openIdConnectUrl

  def further_validation(%{"type" => "apiKey", "name" => _, "in" => "query"}),  do: {:ok}
  def further_validation(%{"type" => "apiKey", "name" => _, "in" => "header"}), do: {:ok}
  def further_validation(%{"type" => "apiKey", "name" => _, "in" => "cookie"}), do: {:ok}
  def further_validation(%{"type" => "apiKey", "name" => _, "in" => location}), do: {:error, SecurityScheme, "apiKey security data cannot be in #{location}"}
  def further_validation(%{"type" => "apiKey", "in" => _}),                     do: {:error, SecurityScheme, "apiKey security requires a name parameter."}
  def further_validation(%{"type" => "apiKey"}),                                do: {:error, SecurityScheme, "apiKey security requires an in parameter."}

  def further_validation(%{"type" => "http", "scheme" => _scheme}) do
    #TODO: check HTTP RFC 7235 to correctly identify valid schemes.
    IO.puts("warning: http security schemes are currently not correctly parsed.")
    {:ok}
  end
  def further_validation(%{"type" => "http"}), do: {:error, SecurityScheme, "http security requires an RFC7235 scheme"}

  def further_validation(%{"type" => "oauth2", "flows" => _}), do: {:ok}
  def further_validation(%{"type" => "oauth2"}), do: {:error, SecurityScheme, "oauth2 security requires a flow object"}

  def further_validation(%{"type" => "openIdConnect", "openIdConnectUrl" => _}), do: {:ok}
  def further_validation(%{"type" => "openIdConnect"}), do: {:error, SecurityScheme, "openIdConnect requires a connection URL"}

  def further_validation(%{}), do: {:error, SecurityScheme, "there is an error in the type of your security scheme."}
end

defmodule Exaggerate.Validation.Flows do

  import Exaggerate.Validation.Helpers

  pass_validate()
end

defmodule Exaggerate.Validation.Flow do

  import Exaggerate.Validation.Helpers

  pass_validate()
end
