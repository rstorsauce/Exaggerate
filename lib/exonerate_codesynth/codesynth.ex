defmodule Exonerate.Codesynth do

  def buildmodulestring(modulename, schemaname, schema) do
    """
      defmodule #{modulename} do
        #{fullvalidator(schemaname, schema)}
      end
    """ |> Code.format_string! |> Enum.join
  end


  def additionalmethodstring(name, %{"additionalProperties" => map}) when is_map(map), do: Exonerate.Codesynth.fullvalidator("#{name}_additionals",map)
  def additionalmethodstring(_, _), do: ""

  def patternmethodstring(name, %{"patternProperties" => map}) when is_map(map) do
    map |> Enum.with_index
        |> Enum.map(fn {{k,v},idx} ->
          Exonerate.Codesynth.fullvalidator("pattern_#{idx}_#{name}", v)
        end)
        |> Enum.join("\n\n")
  end
  def patternmethodstring(_,_), do: ""

  def subschemastring(name, %{"items" => list}) when is_list(list) do
    list |> Enum.with_index
         |> Enum.map(fn {v,idx} ->
           Exonerate.Codesynth.fullvalidator("#{name}_#{idx}", v)
         end)
         |> Enum.join("\n\n")
  end
  def subschemastring(name, %{"properties" => map}) when is_map(map) do
    map |> Enum.map(fn {k,v} ->
          Exonerate.Codesynth.fullvalidator("#{name}_#{k}", v)
        end)
        |> Enum.join("\n\n")
  end
  def subschemastring(_,_), do: ""

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
          "Regex.match?(k, @patternprop_#{idx}_#{name}) -> validate_pattern_#{idx}_#{name}(v)"
        end)
        |> Enum.join("\n")
  end
  def matching_calls(_name, _), do: ""

  def default_call(_name, %{"additionalProperties" => false}),                do: "true -> {:error, \"extra property \#{k} found\"}"
  def default_call(name,  %{"additionalProperties" => map}) when is_map(map), do: "true -> validate_#{name}_additionals(v)"
  def default_call(_name, _),                                                 do: "true -> :ok"

  def simpleobject(map = %{"type" => "array", "items" => items}) when is_map(items), do: false
  def simpleobject(map = %{"type" => "array", "items" => items}) when is_list(items), do: true
  def simpleobject(map = %{"type" => "object"}), do: (!Map.has_key?(map, "properties") || (map["properties"] |> Map.keys |> length <= 1))
                                                        && (!Map.has_key?(map, "additionalProperties"))
                                                        && (!Map.has_key?(map, "patternProperties"))
  def simpleobject(_), do: true

  def validateeachstring(name, map = %{"type" => "array", "items" => list}) when is_list(list) and length(list) > 0 do
    modfnstr = 0..(length(list) - 1)  |> Enum.map( fn i -> "&__MODULE__.validate_#{name}_#{i}/1" end)
                                      |> Enum.join(",")
    """
      def validate_#{name}_all(val) do
        val |> Enum.zip(val, [#{modfnstr}])
            |> Enum.map(fn {a, f} -> f.(a) end)
            |> Exonerate.error_reduction
      end
    """
  end
  def validateeachstring(name, map = %{"type" => "array", "items" => schema}) when is_map(schema), do: fullvalidator("each_#{name}", schema)
  def validateeachstring(name, map = %{"type" => "object"}) do
    if simpleobject(map) do
      ""
    else
      default_calls = if (map["additionalProperties"] == false), do: {}
      """
        def validate_each_#{name}({k,v}) do
          cond do
            #{subschema_calls(name, map)}
            #{matching_calls(name, map)}
            #{default_call(name, map)}
          end
        end
      """
    end
  end
  def validateeachstring(_,_), do: ""

  #assemble a regex string
  def regexstring(name, spec), do: regexes(name, spec) |> regexproc
  def regexproc([]), do: ""
  def regexproc(arr), do: Enum.join(arr, "\n")

  #all the different ways that a regex can happen:
  def regexes(name, spec = %{"pattern" => p}), do: ["@pattern_#{name} Regex.compile(\"#{p}\")\n" | regexes(name, Map.delete(spec, "pattern"))]
  def regexes(name, spec = %{"patternProperties" => p}) do
    (p |> Map.keys
       |> Enum.with_index
       |> Enum.map(fn {pp, idx} -> "@patternprop_#{idx}_#{name} Regex.compile(\"#{pp}\")\n" end))
       ++ regexes(name, Map.delete(spec, "patternProperties"))
  end
  def regexes(_name, _), do: []

  #assemble a guard string.
  def guardstring(spec), do: guards(spec) |> guardproc
  def guardproc([]), do: ""
  def guardproc(arr), do: " and " <> Enum.join(arr, " and ")

  #all the different guards that can happen:
  def guards(spec = %{"minLength" => l}),  do: ["(length(val) >= #{l})" | guards(Map.delete(spec, "minLength"))]
  def guards(spec = %{"maxLength" => l}),  do: ["(length(val) <= #{l})" | guards(Map.delete(spec, "maxLength"))]
  def guards(spec = %{"multipleOf" => v}), do: ["(rem(val, #{v}) == 0)" | guards(Map.delete(spec, "multipleOf"))]

  def guards(spec = %{"minimum" => v, "exclusiveMinimum" => true}), do: ["(val > #{v})" | guards(spec |> Map.delete("minimum") |> Map.delete("exclusiveMinimum"))]
  def guards(spec = %{"maximum" => v, "exclusiveMaximum" => true}), do: ["(val < #{v})" | guards(spec |> Map.delete("maximum") |> Map.delete("exclusiveMaximum"))]

  def guards(spec = %{"minimum" => v}),    do: ["(val >= #{v})" |         guards(Map.delete(spec, "minimum"))]
  def guards(spec = %{"maximum" => v}),    do: ["(val <= #{v})" |         guards(Map.delete(spec, "maximum"))]

  def guards(spec = %{"additionalItems" => false, "items" => array}) when is_list(array) do
    ["(length(val) <= #{length(array)})" | guards(spec |> Map.delete("additionalItems"))]
  end

  def guards(spec = %{"minItems" => l}),   do: ["(length(val) >= #{l})" | guards(Map.delete(spec, "minItems"))]
  def guards(spec = %{"maxItems" => l}),   do: ["(length(val) <= #{l})" | guards(Map.delete(spec, "maxItems"))]
  def guards(_), do: []

  @fmt_map %{"date-time" => "datetime", "email" => "email", "hostname" => "hostname", "ipv4" => "ipv4", "ipv6" => "ipv6", "uri" => "uri"}

  def bodystring(name, spec), do: bodyproc(name, bodyfns(name, spec), simpleobject(spec))
  def bodyproc(name, [], true), do: ":ok"
  def bodyproc(name, [], false), do: "Enum.map(val, &__MODULE__.validate_each_#{name}/1) |> Exonerate.error_reduction"
  def bodyproc(name, [singleton], true), do: singleton
  def bodyproc(name, [singleton], false), do: "[#{singleton} | Enum.map(val, &__MODULE__.validate_each_#{name}/1)] |> Exonerate.error_reduction"
  def bodyproc(name, arr, true), do: "[" <> Enum.join(arr, ",") <> "] |> Exonerate.error_reduction"
  def bodyproc(name, arr, false), do: "([" <> Enum.join(arr, ",") <> "] ++ Enum.map(val, &__MODULE__.validate_each_#{name}/1)) |> Exonerate.error_reduction"

  #some things can't be in guards, so we put them in bodies:
  def bodyfns(name, spec = %{"pattern" => _p}), do: ["check_regex(@regex_pattern_#{name}, val)" | bodyfns(name, Map.delete(spec, "pattern"))]
  def bodyfns(name, spec = %{"format" => p}), do: ["check_format_#{@fmt_map[p]}(val)" | bodyfns(name, Map.delete(spec, "format"))]

  def bodyfns(name, spec = %{"minProperties" => p}), do: ["check_minproperties(val, #{p})" | bodyfns(name, Map.delete(spec, "minProperties"))]
  def bodyfns(name, spec = %{"maxProperties" => p}), do: ["check_maxproperties(val, #{p})" | bodyfns(name, Map.delete(spec, "maxProperties"))]
  def bodyfns(name, spec = %{"dependencies" => d}) do
    (d |> Enum.map(fn {k, v} -> "check_dependencies(val, \"#{k}\", #{inspect v})" end)) ++ bodyfns(name, Map.delete(spec, "dependencies"))
  end
  def bodyfns(name, spec = %{"properties" => p}) do
    if (p |> Map.keys |> length == 1) && (simpleobject(spec)) do
      (p |> Enum.map(fn {k, v} -> "validate_#{name}_#{k}(val[\"#{k}\"])" end)) ++ bodyfns(name, Map.delete(spec, "properties"))
    else
      bodyfns(name, Map.delete(spec, "properties"))
    end
  end
  def bodyfns(name, spec = %{"uniqueItems" => true}), do: ["is_unique(val)" | bodyfns(name, Map.delete(spec, "uniqueItems"))]
  def bodyfns(name, spec = %{"items" => list}) when is_list(list) and length(list) > 0, do: ["validate_test_all(val)" | bodyfns(name, Map.delete(spec, "items"))]
  def bodyfns(_name, _), do: []

  #one last special sugar for objects
  def requiredstring(%{"required" => list}), do: Enum.map(list, fn s -> ~s("#{s}" => _) end) |> Enum.join(",") |> fn s -> "=%{#{s}}" end.()
  def requiredstring(_), do: ""

  def typeguard("string"), do: "is_binary(val)"
  def typeguard("integer"), do: "is_integer(val)"
  def typeguard("number"), do: "is_number(val)"
  def typeguard("boolean"), do: "is_boolean(val)"
  def typeguard("object"), do: "is_map(val)"
  def typeguard("array"), do: "is_list(val)"
  def typeguard("null"), do: "is_nil(val)"
  def typeguard(arr) when is_list(arr), do: Enum.map(arr, &Exonerate.Codesynth.typeguard/1) |> Enum.join(" or ")

  @valid_types ["string", "integer", "number", "boolean", "object", "array"]

  def validator(name, schema = %{"type" => type}) when is_list(type) or (type in @valid_types) do
    """
      #{regexstring(name,schema)}
      #{additionalmethodstring(name, schema)}
      #{patternmethodstring(name, schema)}
      #{subschemastring(name, schema)}
      #{validateeachstring(name, schema)}
      def validate_#{name}(val #{requiredstring(schema)}) when #{typeguard(type)}#{guardstring(schema)}, do: #{bodystring(name, schema)}
    """ |> Code.format_string! |> Enum.join
  end

  #special case values:
  def validator(name, true) do
    """
      def validate_#{name}(_), do: :ok
    """ |> Code.format_string! |> Enum.join
  end
  def validator(name, false), do: ""

  def validator(name, %{"type" => "null"}) do
    """
      def validate_#{name}(nil), do: :ok
    """ |> Code.format_string! |> Enum.join
  end

  #the finalizer decides whether or not we want to trap invalid schema elements.
  #if a "type" specification has been made, then we do, if not, then the schema
  #is permissive.
  def finalizer(name, %{"type" => _}), do: "def validate_#{name}(val), do: {:error, \"\#{inspect val} does not conform to JSON schema\"}"
  def finalizer(name, %{}), do: "def validate_#{name}(val), do: :ok"

  def fullvalidator(name, schema) do
    validator(name, schema) <> "\n" <> finalizer(name, schema)
  end

end
