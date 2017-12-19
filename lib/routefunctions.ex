defmodule Exaggerate.Routefunctions.Helpers do

  #TODO: implement schema checking methods in the route_options macro.
  defmacro route_options(functions) do
    functions |> Enum.map(fn f ->
      quote do
        def unquote(f)(conn, param_name, :required) do
          res = body_parameter(conn, param_name)
          if res, do: {:ok, res}, else: {:error, 422, "required parameter #{param_name} is missing"}
        end
      end
    end
  end
end

defmodule Exaggerate.Routefunctions do

  route_options [:body_parameter, :query_parameter, :cookie_parameter, :formData_parameter]

  def query_parameter(conn, param_name), do: conn.query_params[param_name]

  def header_parameter(conn, param_name), do: conn.request_headers[param_name]

  def cookie_parameter(conn, param_name), do: throw("cookies parameters not currently supported")

  def body_parameter(conn, param_name), do: conn.body_params[param_name]
  def formData_parameter(conn, param_name),do: conn.params[param_name]

  ##############################################################################

  @doc """
    examines the content and sends an response of the appropriate type based on
    the response content specifications in the request header.

    several default content values:
    send_formatted(conn, code, %{:file => filename}) -> sends a file.  you can specify the response mimetype by setting :mimetype in the map.
    send_formatted(conn, code, map)                  -> XML, JSON, text, or text/html
    send_formatted(conn, code, text)                 -> text (possibly detecting XML)
  """
  def send_formatted(conn, code, filemap = %{:file => filename, :mimetype => mimetype}) do
    conn |> update_resp_header("Content-Type", mimetype, fn _ -> mimetype end)
         |> send_file(code, filemap)
  end
  def send_formatted(conn, code, filemap = %{:file => filename}), do: send_file(conn, code, filename)

  @JSONEncoder Application.get_env(:json_encoder)
  @HTMLEncoder Application.get_env(:html_encoder)

  def send_formatted(conn, code, map) when is_map(map) do
    {encoded_res, mimetype} = case response_type(conn) do
      #:xml ->  {XMLEncoder.encode!(map),  }
      {:json, mimetype} -> {@JSONEncoder.encode!(map), mimetype}
      {:text, mimetype} -> {@JSONEncoder.encode!(map), mimetype}
      {:html, mimetype} -> {@HTMLEncoder.encode!(map), mimetype}
    end
    conn |> update_resp_header("Content-Type", mimetype, fn _ -> mimetype end)
         |> send_resp(code, encoded_res)
  end

  def send_formatted(conn, code, text) when is_binary(text) do
    {encoded_res, mimetype} = case response_type(conn) do
      {:json, mimetype} -> {@JSONEncoder.encode!(%{"text" => text}), mimetype}
      {:text, mimetype} -> {text, mimetype}
      {:html, mimetype} -> {@HTMLEncoder.bodyonly(text), mimetype}
    end
    conn |> update_resp_header("Content-Type", mimetype, fn _ -> mimetype end)
         |> send_resp(code, encoded_res)
  end

end
