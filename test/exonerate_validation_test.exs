defmodule ExonerateValidationBasicTest do
  use ExUnit.Case, async: true

  test "boolean json schemas are valid" do
    assert Exonerate.Validation.isvalid(true)
    assert Exonerate.Validation.isvalid(false)
  end

  test "empty json schemas are valid" do
    assert Exonerate.Validation.isvalid(%{})
    assert Exonerate.Validation.isvalid(%{})
  end

  test "primitive json types are valid" do
    assert Exonerate.Validation.isvalid(%{"type" => "string"})
    assert Exonerate.Validation.isvalid(%{"type" => "integer"})
    assert Exonerate.Validation.isvalid(%{"type" => "number"})
    assert Exonerate.Validation.isvalid(%{"type" => "boolean"})
    assert Exonerate.Validation.isvalid(%{"type" => "null"})
    assert Exonerate.Validation.isvalid(%{"type" => "object"})
    assert Exonerate.Validation.isvalid(%{"type" => "array"})
  end

  test "unknown parameters are invalid" do
    refute Exonerate.Validation.isvalid(%{"foo" => "bar"})
  end

  test "minLength and maxLength are valid only for strings." do
    assert Exonerate.Validation.isvalid(%{"type" => "string", "minLength" => 3})
    assert Exonerate.Validation.isvalid(%{"type" => "string", "maxLength" => 3})

    refute Exonerate.Validation.isvalid(%{"type" => "string", "maxLength" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "maxLength" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "maxLength" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "maxLength" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "minLength" => 3})
  end

  test "pattern is valid only for strings." do
    assert Exonerate.Validation.isvalid(%{"type" => "string", "pattern" => "regex"})

    refute Exonerate.Validation.isvalid(%{"type" => "string", "regex" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "regex" => "regex"})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "regex" => "regex"})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "regex" => "regex"})
  end

  test "format is valid only for strings." do
    assert Exonerate.Validation.isvalid(%{"type" => "string", "format" => "uri"})

    refute Exonerate.Validation.isvalid(%{"type" => "string", "format" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "format" => "uri"})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "format" => "uri"})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "format" => "uri"})
  end

  test "multipleOf is valid only for numbers." do
    assert Exonerate.Validation.isvalid(%{"type" => "integer", "multipleOf" => 10})
    assert Exonerate.Validation.isvalid(%{"type" => "number", "multipleOf" => 10})

    refute Exonerate.Validation.isvalid(%{"type" => "integer", "multipleOf" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "multipleOf" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "multipleOf" => 10})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "multipleOf" => 10})
  end

  test "minimum and maximum are valid only for numerics." do
    assert Exonerate.Validation.isvalid(%{"type" => "integer", "minimum" => 3})
    assert Exonerate.Validation.isvalid(%{"type" => "integer", "maximum" => 3})
    assert Exonerate.Validation.isvalid(%{"type" => "number", "minimum" => 3})
    assert Exonerate.Validation.isvalid(%{"type" => "number", "maximum" => 3})

    refute Exonerate.Validation.isvalid(%{"type" => "integer", "maximum" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "minimum" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "maximum" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "minimum" => 3})
  end

  test "exclusiveminmax is valid only when the corresponding exists" do
    assert Exonerate.Validation.isvalid(%{"type" => "integer", "minimum" => 3, "exclusiveMinimum" => true})
    assert Exonerate.Validation.isvalid(%{"type" => "integer", "maximum" => 3, "exclusiveMaximum" => true})
    assert Exonerate.Validation.isvalid(%{"type" => "number", "minimum" => 3, "exclusiveMinimum" => true})
    assert Exonerate.Validation.isvalid(%{"type" => "number", "maximum" => 3, "exclusiveMaximum" => true})

    refute Exonerate.Validation.isvalid(%{"type" => "integer", "maximum" => 3, "exclusiveMinimum" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "minimum" => 3, "exclusiveMaximum" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "exclusiveMinimum" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "exclusiveMaximum" => true})
  end

  test "properties is valid only for objects" do
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}})

    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => "not a map"})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "properties" => %{}})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "properties" => %{}})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "properties" => %{}})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "properties" => %{}})
  end

  test "properties properties must be valid json schemata" do
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{"subobj" => true}})
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{"subobj" => false}})
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{"subobj" => %{"type" => "string"}}})

    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{"subobj" => %{"type" => "foo"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{"subobj" => %{"foo" => "bar"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{"subobj" => %{"type" => "string", "maximum" => 3}}})
  end

  test "additional properties may be true, false, or a schema" do
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}, "additionalProperties" => true})
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}, "additionalProperties" => false})
    assert Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}, "additionalProperties" => %{"type" => "string"}})

    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}, "additionalProperties" => "not ok."})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "additionalProperties" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "additionalProperties" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}, "additionalProperties" => %{"foo" => "bar"}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "properties" => %{}, "additionalProperties" => %{"type" => "foo"}})
  end

  test "required properties must be inside the properties list" do
    assert Exonerate.Validation.isvalid(%{"type" => "object",
                                          "properties" => %{"name" => %{"type" => "string"},
                                                            "email" => %{"type" => "string"},
                                                            "address" => %{"type" =>"string"},
                                                            "telephone" => %{"type" => "string"}},
                                          "required" => ["name", "email"]})

    refute Exonerate.Validation.isvalid(%{"type" => "object",
                                          "properties" => %{"name" => %{"type" => "string"},
                                                            "email" => %{"type" => "string"},
                                                            "address" => %{"type" =>"string"},
                                                            "telephone" => %{"type" => "string"}},
                                          "required" => ["name", "foo"]})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "required" => ["name", "foo"]})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "required" => ["name", "foo"]})
  end

  test "objects may have min/max property count" do
    assert Exonerate.Validation.isvalid(%{"type" => "object", "minProperties" => 3})
    assert Exonerate.Validation.isvalid(%{"type" => "object", "maxProperties" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "maxProperties" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "maxProperties" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "maxProperties" => 3})
  end

  test "property dependencies work for both key lists and object descriptions" do
    #we're not going to assert that the existing keys must exist in properties property.
    assert Exonerate.Validation.isvalid(%{"type" => "object", "dependencies" => %{"credit_card" => ["billing_address"]}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "dependencies" => %{"credit_card" => [%{"foo" => "bar"}]}})
    assert Exonerate.Validation.isvalid(%{"type" => "object", "dependencies" => %{"credit_card" => %{"type" => "string"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "dependencies" => %{"credit_card" => %{"foo" => "bar"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "dependencies" => %{"credit_card" => %{"type" => "bar"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "dependencies" => %{"credit_card" => "billing_address"}})
  end

  test "pattern properties have expected properties for objects" do
    assert Exonerate.Validation.isvalid(%{"type" => "object", "patternProperties" => %{"credit_card" => %{"type" => "string"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "patternProperties" => %{"credit_card" => %{"foo" => "bar"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "patternProperties" => %{"credit_card" => %{"type" => "bar"}}})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "patternProperties" => %{"credit_card" => %{"type" => "string"}}})
  end

  test "array items property works for a single schema" do
    #we're not going to assert that the existing keys must exist in properties property.
    assert Exonerate.Validation.isvalid(%{"type" => "array", "items" => %{"type" => "string"}})

    refute Exonerate.Validation.isvalid(%{"type" => "array", "items" => %{"type" => "foo"}})
    refute Exonerate.Validation.isvalid(%{"type" => "array", "items" => %{"foo" => "bar"}})
    refute Exonerate.Validation.isvalid(%{"type" => "array", "items" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "object", "items" => %{"type" => "string"}})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "items" => %{"type" => "string"}})
  end

  test "array items property works for an array schema" do
    #we're not going to assert that the existing keys must exist in properties property.
    assert Exonerate.Validation.isvalid(%{"type" => "array", "items" => [%{"type" => "string"}, %{"type" => "integer"}]})
    refute Exonerate.Validation.isvalid(%{"type" => "array", "items" => [%{"type" => "string"}, %{"type" => "foo"}]})
    refute Exonerate.Validation.isvalid(%{"type" => "array", "items" => [%{"type" => "string"}, %{"foo" => "bar"}]})
  end

  test "additionalItems and uniqueItems works for arrays" do
    #we're not going to assert that the existing keys must exist in properties property.
    assert Exonerate.Validation.isvalid(%{"type" => "array", "uniqueItems" => true})
    assert Exonerate.Validation.isvalid(%{"type" => "array", "items" => [%{"type" => "string"}], "additionalItems" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "array", "additionalItems" => true})

    refute Exonerate.Validation.isvalid(%{"type" => "string", "uniqueItems" => true})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "additionalItems" => true})
  end

  test "minItems and maxItems are valid only for arrays." do
    assert Exonerate.Validation.isvalid(%{"type" => "array", "minItems" => 3})
    assert Exonerate.Validation.isvalid(%{"type" => "array", "maxItems" => 3})

    refute Exonerate.Validation.isvalid(%{"type" => "array", "maxItems" => "foo"})
    refute Exonerate.Validation.isvalid(%{"type" => "string", "maxItems" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "maxItems" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "number", "maxItems" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "null", "maxItems" => 3})
    refute Exonerate.Validation.isvalid(%{"type" => "integer", "minItems" => 3})
  end

end
