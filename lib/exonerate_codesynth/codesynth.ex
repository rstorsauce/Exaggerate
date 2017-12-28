defmodule Exonerate.Codesynth do

  def buildmodule_string(modulename, schemaname, schema) do
    """
      defmodule #{modulename} do
        #{validator_string(schemaname, schema)}
      end
    """ |> Code.format_string! |> Enum.join
  end

  ##############################################################################
  ## main subcomponent functions

  def validator_string(name, schema) do
    Enum.join([dependencies_string(name, schema), validatorfn_string(name, schema), finalizer_string(name, schema)], "\n")
  end

  # the dependencies strings are components (regex + fun) that we need to do
  # some of the heavy lifting for things we can't simply use guards on, also for
  # things where we need direct recursion to evaluate subschemas.
  def dependencies_string(name, schema) do
    """
      #{regexstring(name, schema)}
      #{additionals_string(name, schema)}
      #{patternpropertystring(name, schema)}
      #{subschemastring(name, schema)}
      #{validateeachstring(name, schema)}
    """
  end

  # the validator function is the main workhorse which does much of the
  # processing of the string.  It mostly contains guards which filter the
  # processing, but also body components that are used for map/reduce type
  # assembly of validation results.

  #single special case values:
  #true and false are taken care of by the finalizer.
  def validatorfn_string(name, bool) when is_boolean(bool), do: ""

  #nil requires a special handler.
  def validatorfn_string(name, %{"type" => "null"}) do
    """
      def validate_#{name}(nil), do: :ok
    """ |> Code.format_string! |> Enum.join
  end

  #these three cases are when there's type information; they pass to the triplet definition.
  def validatorfn_string(name, schema = %{"type" => type}) when is_binary(type) do
    validatorfn_string(name, schema, type)
  end

  def validatorfn_string(name, schema = %{"type" => type}) when is_list(type) do
    Enum.map(type, &validatorfn_string(name, schema, &1)) |> Enum.join("\n")
  end

  def validatorfn_string(name, schema = %{}) do
     validatorfn_string(name, Map.put(schema, "type", find_type_dependencies(schema)))
  end

  ## the triplet type actually passes critical type information on to subcomponents
  def validatorfn_string(name, schema, type) do
    """
       def validate_#{name}(val #{requiredstring(schema, type)}) #{guardstring(schema, type)}, do: #{bodystring(name, schema, type)}
    """
  end

  # the finalizer decides whether or not we want to trap invalid schema elements.
  # if a "type" specification has been made, then we do, if not, then the schema
  # is permissive.
  def finalizer_string(name, %{"type" => _}), do: "def validate_#{name}(val), do: {:error, \"\#{inspect val} does not conform to JSON schema\"}"
  def finalizer_string(name, false), do:          "def validate_#{name}(val), do: {:error, \"\#{inspect val} does not conform to JSON schema\"}"
  def finalizer_string(name, _), do:              "def validate_#{name}(val), do: :ok"

  ##############################################################################
  ## dependencies_string subcomponents
  ##

  # precompiled regexes can come from either string patterns or object key
  # patterns, which are called "patternProperties" in JSONSchema.

  def regexstring(name, spec), do: regexes(name, spec) |> Enum.join("\n")

  def regexes(name, spec = %{"pattern" => p}), do: ["@pattern_#{name} Regex.compile(\"#{p}\")\n" | regexes(name, Map.delete(spec, "pattern"))]
  def regexes(name, spec = %{"patternProperties" => p}) do
    (p |> Map.keys
       |> Enum.with_index
       |> Enum.map(fn {pp, idx} -> "@patternprop_#{name}_#{idx} Regex.compile(\"#{pp}\")\n" end))
       ++ regexes(name, Map.delete(spec, "patternProperties"))
  end
  def regexes(_name, _), do: []

  # additional properties are properties that have to be validated but do not
  # correspond to a particular defined property.  These will be generated as
  # functions with __additionals appended (this could cause a collision if
  # someone makes JSONSchema requiring a key value of _additionals for an object
  # on top of one demanding additionals.)
  def additionals_string(name, schema = %{"additionalProperties" => ap}) when is_map(ap) do
    [validator_string("#{name}__additionalProperties",ap), additionals_string(name, Map.delete(schema, "additionalProperties"))] |> Enum.join("\n")
  end
  def additionals_string(name, schema = %{"additionalItems" => ai}) when is_map(ai) do
    [validator_string("#{name}__additionalItems",ai),      additionals_string(name, Map.delete(schema, "additionalItems"))]      |> Enum.join("\n")
  end
  def additionals_string(_, _), do: ""

  # pattern properties are object properties that have to be validated but do not
  # have a definitive map name.  These will be validated by sequential functions
  # that are mapped to unique numbers.
  def patternpropertystring(name, %{"patternProperties" => map}) when is_map(map) do
    map |> Enum.with_index
        |> Enum.map(fn {{k,v},idx} ->
          validator_string("#{name}__pattern_#{idx}", v)
        end)
        |> Enum.join("\n\n")
  end
  def patternpropertystring(_,_), do: ""

  # subschemas are recursive validations that come from either arrays or
  # object properties
  def subschemastring(name, %{"items" => list}) when is_list(list) do
    list |> Enum.with_index
         |> Enum.map(fn {v,idx} ->
           validator_string("#{name}_#{idx}", v)
         end)
         |> Enum.join("\n\n")
  end
  def subschemastring(name, %{"properties" => map}) when is_map(map) do
    map |> Enum.map(fn {k,v} ->
          validator_string("#{name}_#{k}", v)
        end)
        |> Enum.join("\n\n")
  end
  def subschemastring(_,_), do: ""

  # validate_each functions are functions that remap onto the subschema functions
  # intended to be called as a result of a Enum.map in the main validator function
  # note that maps map over {k, v} and lists map over {v}.

  def validateeachstring(name, map = %{"type" => "array", "items" => list, "additionalItems" => schema}) when is_list(list) and is_map(schema) do
    itemvalidationarray = 0..(length(list) - 1)  |> Enum.map( fn i -> "&__MODULE__.validate_#{name}_#{i}/1" end)
                                                 |> Enum.join(",")
    """
      def validate_#{name}__all(val) do
        check_additionalitems(val, [#{itemvalidationarray}], &__MODULE__.validate_#{name}__additionalItems/1)
      end
    """
  end

  def validateeachstring(name, map = %{"type" => "array", "items" => list}) when is_list(list) and length(list) > 0 do
    itemvalidationarray = 0..(length(list) - 1)  |> Enum.map( fn i -> "&__MODULE__.validate_#{name}_#{i}/1" end)
                                                 |> Enum.join(",")
    """
      def validate_#{name}__all(val) do
        val |> Enum.zip(val, [#{itemvalidationarray}])
            |> Enum.map(fn {a, f} -> f.(a) end)
            |> Exonerate.error_reduction
      end
    """
  end
  def validateeachstring(name, map = %{"type" => "array", "items" => schema}) when is_map(schema), do: validator_string("each_#{name}", schema)
  def validateeachstring(name, map = %{"type" => "object"}) do
    default_calls = if (map["additionalProperties"] == false), do: {}
    if simpleobject(map, "object") do
      ""
    else
      """
        def validate_#{name}__each({k,v}) do
          cond do
            #{subschema_calls(name, map)}
            #{matching_calls(name, map)}
            #{default_call(name, map)}
          end
        end
      """
    end
  end
  def validateeachstring(name, schema = %{"type" => typearr}) when is_list(typearr) do
    maybe_object = if "object" in typearr, do: validateeachstring(name, Map.put(schema, "type", "object")), else: ""
    maybe_array  = if "array"  in typearr, do: validateeachstring(name, Map.put(schema, "type", "array")),  else: ""
    Enum.join([maybe_object, maybe_array], "\n")
  end
  def validateeachstring(name, %{"type" => _}), do: ""
  def validateeachstring(name, bool) when is_boolean(bool), do: ""
  #for untyped schemas we have to decide if we need these validation guards, we
  #do this by redispatching over our find_type_dependencies utility.
  def validateeachstring(name, schema) do
    validateeachstring(name, Map.put(schema, "type", find_type_dependencies(schema)))
  end

  # validate_each helper functions
  def subschema_calls(name, %{"properties" => map}) do
    map |> Enum.map(fn {k,v} ->
          "\"#{k}\" = k -> validate_#{name}_#{k}(v)"
        end)
        |> Enum.join("\n")
  end
  def subschema_calls(_,_), do: ""

  def matching_calls(name, %{"patternProperties" => map}) do
    map |> Enum.with_index
        |> Enum.map(fn {{k,v}, idx} ->
          "Regex.match?(k, @patternprop_#{name}_#{idx}) -> validate_#{name}__pattern_#{idx}(v)"
        end)
        |> Enum.join("\n")
  end
  def matching_calls(_name, _), do: ""

  def default_call(_name, %{"additionalProperties" => false}),                do: "true -> {:error, \"extra property \#{k} found\"}"
  def default_call(name,  %{"additionalProperties" => map}) when is_map(map), do: "true -> validate_#{name}__additionalProperties(v)"
  def default_call(_name, _),                                                 do: "true -> :ok"


  ##############################################################################
  ## validator function subcomponents
  ##

  def simpleobject(%{"items" => items}, "array") when is_map(items),  do: false
  def simpleobject(%{"items" => items}, "array") when is_list(items), do: true

  def simpleobject(map, "object"), do: (!Map.has_key?(map, "properties") || (map["properties"] |> Map.keys |> length <= 1))
                                                        && (!Map.has_key?(map, "additionalProperties"))
                                                        && (!Map.has_key?(map, "patternProperties"))
  def simpleobject(_,_), do: true

  #assemble a guard string.
  def guardstring(spec, type), do: guards(spec, type) |> guardproc(type)
  def guardproc([], type), do: "when #{guardverb(type)}"
  def guardproc(arr, type), do: "when #{guardverb(type)} and " <> Enum.join(arr, " and ")

  def guardverb("string"), do: "is_binary(val)"
  def guardverb("integer"), do: "is_integer(val)"
  def guardverb("number"), do: "is_number(val)"
  def guardverb("boolean"), do: "is_boolean(val)"
  def guardverb("none"), do: "is_nil(val)"
  def guardverb("array"), do: "is_list(val)"
  def guardverb("object"), do: "is_map(val)"

  #all the different guards that can happen:
  def guards(spec = %{"minLength" => l}, "string"),  do: ["(length(val) >= #{l})" | guards(Map.delete(spec, "minLength"), "string")]
  def guards(spec = %{"maxLength" => l}, "string"),  do: ["(length(val) <= #{l})" | guards(Map.delete(spec, "maxLength"), "string")]
  def guards(spec = %{"multipleOf" => v}, type) when type in ["integer","number"], do: ["(rem(val, #{v}) == 0)" | guards(Map.delete(spec, "multipleOf"), type)]

  def guards(spec = %{"minimum" => v, "exclusiveMinimum" => true}, type) when type in ["integer", "number"], do: ["(val > #{v})" | guards(spec |> Map.delete("minimum") |> Map.delete("exclusiveMinimum"), type)]
  def guards(spec = %{"maximum" => v, "exclusiveMaximum" => true}, type) when type in ["integer", "number"], do: ["(val < #{v})" | guards(spec |> Map.delete("maximum") |> Map.delete("exclusiveMaximum"), type)]
  def guards(spec = %{"minimum" => v}, type) when type in ["integer","number"],    do: ["(val >= #{v})" |         guards(Map.delete(spec, "minimum"), type)]
  def guards(spec = %{"maximum" => v}, type) when type in ["integer","number"],    do: ["(val <= #{v})" |         guards(Map.delete(spec, "maximum"), type)]

  def guards(spec = %{"additionalItems" => false, "items" => array}, "array") when is_list(array) do
    ["(length(val) <= #{length(array)})" | guards(spec |> Map.delete("additionalItems"), "array")]
  end
  def guards(spec = %{"minItems" => l}, "array"),   do: ["(length(val) >= #{l})" | guards(Map.delete(spec, "minItems"), "array")]
  def guards(spec = %{"maxItems" => l}, "array"),   do: ["(length(val) <= #{l})" | guards(Map.delete(spec, "maxItems"), "array")]
  def guards(_,_), do: []

  @fmt_map %{"date-time" => "datetime", "email" => "email", "hostname" => "hostname", "ipv4" => "ipv4", "ipv6" => "ipv6", "uri" => "uri"}

  def bodystring(name, schema, type), do: bodyproc(name, bodyfns(name, schema, type), simpleobject(schema, type))
  def bodyproc(name, [], true), do: ":ok"
  def bodyproc(name, [], false), do: "Enum.map(val, &__MODULE__.validate_each_#{name}/1) |> Exonerate.error_reduction"
  def bodyproc(name, [singleton], true), do: singleton
  def bodyproc(name, [singleton], false), do: "[#{singleton} | Enum.map(val, &__MODULE__.validate_each_#{name}/1)] |> Exonerate.error_reduction"
  def bodyproc(name, arr, true), do: "[" <> Enum.join(arr, ",") <> "] |> Exonerate.error_reduction"
  def bodyproc(name, arr, false), do: "([" <> Enum.join(arr, ",") <> "] ++ Enum.map(val, &__MODULE__.validate_each_#{name}/1)) |> Exonerate.error_reduction"

  #some things can't be in guards, so we put them in bodies:
  def bodyfns(name, spec = %{"pattern" => _p}, "string"), do:      ["check_regex(@regex_pattern_#{name}, val)" | bodyfns(name, Map.delete(spec, "pattern"), "string")]
  def bodyfns(name, spec = %{"format" => p},   "string"), do:      ["check_format_#{@fmt_map[p]}(val)" | bodyfns(name, Map.delete(spec, "format"), "string")]

  def bodyfns(name, spec = %{"minProperties" => p}, "object"), do: ["check_minproperties(val, #{p})" | bodyfns(name, Map.delete(spec, "minProperties"), "object")]
  def bodyfns(name, spec = %{"maxProperties" => p}, "object"), do: ["check_maxproperties(val, #{p})" | bodyfns(name, Map.delete(spec, "maxProperties"), "object")]

  def bodyfns(name, spec = %{"dependencies" => d}, "object") do
    (d |> Enum.map(fn {k, v} -> "check_dependencies(val, \"#{k}\", #{inspect v})" end)) ++ bodyfns(name, Map.delete(spec, "dependencies"), "object")
  end

  def bodyfns(name, spec = %{"properties" => p}, "object") do
    if (p |> Map.keys |> length == 1) && (simpleobject(spec, "object")) do
      (p |> Enum.map(fn {k, v} -> "validate_#{name}_#{k}(val[\"#{k}\"])" end)) ++ bodyfns(name, Map.delete(spec, "properties"), "object")
    else
      bodyfns(name, Map.delete(spec, "properties"), "object")
    end
  end
  def bodyfns(name, spec = %{"uniqueItems" => true}, "array"), do: ["is_unique(val)" | bodyfns(name, Map.delete(spec, "uniqueItems"), "array")]
  def bodyfns(name, spec = %{"items" => list}, "array") when is_list(list) and length(list) > 0, do: ["validate_test_all(val)" | bodyfns(name, Map.delete(spec, "items"), "array")]
  def bodyfns(_name, _, _), do: []

  #one last special sugar for objects
  def requiredstring(%{"required" => list}, "object"), do: Enum.map(list, fn s -> ~s("#{s}" => _) end) |> Enum.join(",") |> fn s -> "=%{#{s}}" end.()
  def requiredstring(_, _), do: ""

  @sourcetype %{"minLength" => "string", "maxLength" => "string", "format" => "string",
                "pattern" => "string", "multipleOf" => "number", "minimum" => "number",
                "maximum" => "number", "properties" => "object", "additionalProperties" => "object",
                "required" => "object", "minProperties" => "object", "maxProperties" => "object",
                "dependencies" => "object", "patternProperties" => "object",
                "items" => "array", "uniqueItems" => "array", "additionalItems" => "array",
                "minItems" => "array", "maxItems" => "array"}

  #goes through a list of properties and searches for dependencies
  def find_type_dependencies(schema) do
    schema |> Enum.map(fn {k, _v} -> @sourcetype[k] end)
               |> Enum.filter(& &1)
               |> Enum.uniq
  end

end
