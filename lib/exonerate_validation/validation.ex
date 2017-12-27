defmodule Exonerate.Validation do

  require Logger

  def isvalid(map), do: validate(map) == :ok

  def error_reduction(arr) when is_list(arr), do: arr |> Enum.reduce(:ok, &Exonerate.Validation.error_reduction/2)
  def error_reduction(:ok, :ok), do: :ok
  def error_reduction(:ok, err), do: err
  def error_reduction(err, _), do: err

  def validate(value), do: validate(value, true)
  def validate(bool, _) when is_boolean(bool), do: :ok
  def validate(%{"$ref" => _}, false), do: :ok  #we can validate references in another step.
  def validate(map, first) when is_map(map) do
    map |> Enum.map(&Exonerate.Validation.validate_kv(&1, map, first))
        |> error_reduction
  end
  def validate(_, _), do: {:error, "invalid type for validation"}

  ##############################################################################
  ## since JSON Schema is a recursive definition, the validate_kv function does
  ## most of the heavy lifting.

  #type handling
  def validate_kv({"type", "string"}, _map, _), do: :ok
  def validate_kv({"type", "integer"}, _map, _), do: :ok
  def validate_kv({"type", "number"}, _map, _), do: :ok
  def validate_kv({"type", "boolean"}, _map, _), do: :ok
  def validate_kv({"type", "null"}, _map, _), do: :ok
  def validate_kv({"type", "object"}, _map, _), do: :ok
  def validate_kv({"type", "array"}, _map, _), do: :ok

  #schema annotation handles
  def validate_kv({"$schema", _}, _map, true), do: :ok
  def validate_kv({"$schema", _}, _map, false), do: {:error, "$schema key not at root"}
  def validate_kv({"id", _}, _map, true), do: :ok
  def validate_kv({"id", _}, _map, false), do: {:error, "id key not at root"}
  def validate_kv({"definitions", map}, _map, true) when is_map(map), do: Enum.map(map, fn {_k,v} -> validate(v, false) end)

  #metadata keywords
  def validate_kv({"title", _}, _map, _), do: :ok
  def validate_kv({"description", _}, _map, _), do: :ok
  def validate_kv({"default", _}, _map, _) do
    Logger.warn("currently default values are not validated aganist the schema type")
    :ok
  end

  #compound schemas
  def validate_kv({"allOf", arr}, _map, _) when is_list(arr), do: Enum.map(arr, &validate(&1, false)) |> error_reduction
  def validate_kv({"anyOf", arr}, _map, _) when is_list(arr), do: Enum.map(arr, &validate(&1, false)) |> error_reduction
  def validate_kv({"oneOf", arr}, _map, _) when is_list(arr), do: Enum.map(arr, &validate(&1, false)) |> error_reduction
  def validate_kv({"not", map}, _map, _) when is_map(map), do: validate(map, false)

  #keyvalue pairs which have a type requirement
  #strings
  def validate_kv({"minLength", int}, %{"type" => "string"}, _) when is_integer(int), do: :ok
  def validate_kv({"maxLength", int}, %{"type" => "string"}, _) when is_integer(int), do: :ok
  def validate_kv({"pattern", regex}, %{"type" => "string"}, _) when is_binary(regex), do: :ok
  def validate_kv({"format", fmt}, %{"type" => "string"}, _) when fmt in ["date-time", "email", "hostname", "ipv4", "ipv6", "uri"], do: :ok
  #numeric
  def validate_kv({"multipleOf", num}, %{"type" => numeric}, _) when (numeric in ["integer", "number"]) and is_number(num), do: :ok
  def validate_kv({"minimum", num}, %{"type" => numeric}, _) when (numeric in ["integer", "number"]) and is_number(num), do: :ok
  def validate_kv({"maximum", num}, %{"type" => numeric}, _) when (numeric in ["integer", "number"]) and is_number(num), do: :ok
  def validate_kv({"exclusiveMinimum", bool}, %{"minimum" => _}, _) when is_boolean(bool), do: :ok
  def validate_kv({"exclusiveMaximum", bool}, %{"maximum" => _}, _) when is_boolean(bool), do: :ok
  #object
  def validate_kv({"properties", obj}, %{"type" => "object"}, _) when is_map(obj), do: Enum.map(obj, fn {_k,v} -> validate(v, false) end) |> error_reduction
  def validate_kv({"additionalProperties", val}, %{"properties" => _}, _), do: validate(val, false)
  def validate_kv({"required", val}, %{"properties" => props}, _) when is_list(val), do: Enum.map(val, fn key -> if key in Map.keys(props), do: :ok, else: {:error, "required item not in property keys"} end) |> error_reduction
  def validate_kv({"minProperties", int}, %{"type" => "object"}, _) when is_integer(int), do: :ok
  def validate_kv({"maxProperties", int}, %{"type" => "object"}, _) when is_integer(int), do: :ok
  def validate_kv({"dependencies", obj}, %{"type" => "object"}, _) when is_map(obj), do: Enum.map(obj, fn {_k, v} -> validate_dependency(v) end) |> error_reduction
  def validate_kv({"patternProperties", obj}, %{"type" => "object"}, _) when is_map(obj), do: Enum.map(obj, fn {_k, v} -> validate(v, false) end) |> error_reduction
  #array
  def validate_kv({"items", obj}, %{"type" => "array"}, _) when is_map(obj), do: validate(obj, false)
  def validate_kv({"items", arr}, %{"type" => "array"}, _) when is_list(arr), do: Enum.map(arr, &validate(&1, false)) |> error_reduction
  def validate_kv({"minItems", int}, %{"type" => "array"}, _) when is_integer(int), do: :ok
  def validate_kv({"maxItems", int}, %{"type" => "array"}, _) when is_integer(int), do: :ok

  def validate_kv({"uniqueItems", bool}, %{"type" => "array"}, _) when is_boolean(bool), do: :ok
  def validate_kv({"additionalItems", bool}, %{"items" => _}, _) when is_boolean(bool), do: :ok

  #other keywords
  def validate_kv({"enum", enum_val}, _map, _) when is_list(enum_val)
                                               when length(enum_val) > 0 do
    Logger.warn("currently enum values are not validated aganist the schema type")
    :ok
  end
  def validate_kv({"enum", enum_val}, _map, _), do: {:error, "invalid enum #{enum_val}"}

  def validate_kv({k, _v}, _map, _), do: {:error, "unrecognized key #{inspect k}"}


  def validate_dependency(list) when is_list(list) do
    list |> Enum.map(&is_binary/1)
         |> Enum.reduce(true, &Kernel.&&/2)
         |> fn true -> :ok
               false -> {:error, "non-string item in dependency list"} end.()
  end
  def validate_dependency(map) when is_map(map), do: validate(map, false)
  def validate_dependency(value), do: {:error, "strange object in dependency list #{inspect value}"}

end
