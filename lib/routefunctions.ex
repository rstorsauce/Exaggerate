defmodule Exaggerate.RouteFunctions.Helpers do

  #TODO: implement schema checking methods in the route_options macro.
  defmacro route_options(functions) do
    functions |> Enum.map(fn f ->
      quote do
        def unquote(f)(conn, param_name, :required) do
          res = unquote(f)(conn, param_name)
          if res, do: {:ok, res}, else: {:error, "required parameter '#{param_name}' is missing"}
        end
      end
    end)
  end
end

defmodule Exaggerate.RouteFunctions do

  import Exaggerate.RouteFunctions.Helpers
  import Plug.Conn, only: [update_resp_header: 4, send_resp: 3, send_file: 3, get_req_header: 2]

  route_options [:body_parameter, :query_parameter, :cookie_parameter, :formData_parameter]

  def query_parameter(conn, param_name), do: conn.query_params[param_name]

  def header_parameter(conn, param_name), do: conn.request_headers[param_name]

  def cookie_parameter(_conn, _param_name), do: throw("cookies parameters not currently supported")

  def requestbody_parameter(conn, validation_fn) do
     validation_fn.(conn)
  end

  #deprecated parameters
  def body_parameter(conn, param_name), do: conn.body_params[param_name]
  def formData_parameter(conn, param_name),do: conn.params[param_name]

  ##############################################################################

  @doc """
    turns a content-type string into a list of mimetypes.

    iex> Exaggerate.RouteFunctions.process_response_string(["text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"]) #==>
    ["text/html","application/xhtml+xml","application/xml","*/*"]
  """

  def process_response_string([s]) when is_binary(s) do
    s |> String.split(",")
      |> Enum.map(fn x -> x |> String.split(";") |> Enum.at(0) end)
  end
  def process_response_string([]), do: ["*/*"]

  @doc """
    assigns the desired response string based on a content-type string list.
    JSON and XML responses are prioritized,  followed by html, */* is lowest-priority.

    iex> Exaggerate.RouteFunctions.match_response_string(["*/*", "application/json"]) #==>
    {:json, "application/json"}

    iex> Exaggerate.RouteFunctions.match_response_string(["text/html", "text/xml"]) #==>
    {:xml, "text/xml"}

    iex> Exaggerate.RouteFunctions.match_response_string(["text/unkown"]) #==>
    {:error, "no matching mimetype"}
  """

  def match_response_string(arr), do: match_response_string(arr, nil)
  #JSON or XML responses get prioritized.
  def match_response_string(["application/json" | _tail], _), do: {:json, "application/json"}
  def match_response_string(["text/xml" | _tail], _), do: {:xml, "text/xml"}

  #text/html beats vague statuses (but not json or xml)
  def match_response_string(["text/html" | tail], _), do: match_response_string(tail, "text/html")

  def match_response_string(["text/plain" | tail], best), do: match_response_string(tail, best || "text/plain")
  def match_response_string(["application/xhtml+xml" | tail], best), do: match_response_string(tail, best || "application/xhtml+xml")
  def match_response_string(["*/*" | tail], best), do: match_response_string(tail, best || "*/*")

  #unrecognized response types pass on "best"
  def match_response_string([_ | tail], best), do: match_response_string(tail, best)
  def match_response_string([], "*/*"), do: {:json, "application/json"}
  def match_response_string([], "text/plain"), do: {:text, "text/plain"}
  def match_response_string([], "text/html"), do: {:html, "text/html"}
  def match_response_string([], nil), do: {:error, "no matching mimetype"}

  def response_type(conn) do
    conn |> get_req_header("accept")
      |> process_response_string
      |> match_response_string
  end

  @doc """
    examines the content and sends an response of the appropriate type based on
    the response content specifications in the request header.

    several default content values:
    send_formatted(conn, code, %{:file => filename}) -> sends a file.  you can specify the response mimetype by setting :mimetype in the map.
    send_formatted(conn, code, map)                  -> XML, JSON, text, or text/html
    send_formatted(conn, code, text)                 -> text (possibly detecting XML)
  """
  def send_formatted(conn, code, [file: filename, mimetype: mimetype]) do
    conn |> update_resp_header("Content-Type", mimetype, fn _ -> mimetype end)
         |> send_file(code, filename)
  end
  def send_formatted(conn, code, [file: filename]), do: send_file(conn, code, filename)

  def send_formatted(conn, code, map) when is_map(map) or is_list(map) do
    {new_code, encoded_res, mimetype} = case response_type(conn) do
      #:xml ->  {XMLEncoder.encode!(map),  }
      {:json, mimetype}  -> {code, Poison.encode!(map), mimetype}
      {:text, mimetype}  -> {code, Poison.encode!(map), mimetype}
      {:html, mimetype}  -> {code, Exaggerate.HTMLEncode.encode!(map), mimetype}
      {:error, errormsg} -> {415, errormsg, "text/html"}
    end
    conn |> update_resp_header("Content-Type", mimetype, fn _ -> mimetype end)
         |> send_resp(new_code, encoded_res)
  end

  def send_formatted(conn, code, text) when is_binary(text) do
    {new_code, encoded_res, mimetype} = case response_type(conn) do
      {:json, mimetype} -> {code, Poison.encode!(%{"text" => text}), mimetype}
      {:text, mimetype} -> {code, text, mimetype}
      {:html, mimetype} -> {code, Exaggerate.HTMLEncode.bodyonly(text), mimetype}
      {:error, errormsg} -> {415, errormsg, "text/html"}
    end
    conn |> update_resp_header("Content-Type", mimetype, fn _ -> mimetype end)
         |> send_resp(new_code, encoded_res)
  end

  def drop_nil_values(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
         {k,nil}, acc -> acc
         {k,v}, acc   -> Map.put(acc, k, v)
       end)
  end

end
