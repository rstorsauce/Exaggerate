defmodule Exaggerate.Responses do

  @type formatted_t :: Exonerate.json | {:file, Path.t}

  alias Exaggerate.Tools

  @spec send_formatted(Plug.Conn.t, non_neg_integer, formatted_t) :: Plug.Conn.t
  def send_formatted(conn, code, content) when code >= 400 and code <= 499 do
    # error condition
    conn
    |> try_json(code, content)
    |> try_text(code, content)
    |> try_html(code, content)
    |> error_out(code, content)
  end
  def send_formatted(conn, code, content)
    when is_binary(content) or is_number(content) do
    #scalar condition
    conn
    |> try_text(code, content)
    |> try_html(code, content)
    |> try_json(code, content)
    |> error_out
  end
  def send_formatted(conn, code, content) do
    #json condition
    conn
    |> try_json(code, content)
    |> try_text(code, content)
    |> try_html(code, content)
    |> error_out
  end

  def try_text(s = %Plug.Conn{state: :sent}, _, _), do: s
  def try_text(conn, code, content) when (code >= 400 and code <= 499) do
    # error condition
    try_with_mimetype(conn, code, "Error #{code}: #{content}", "text/plain")
  end
  def try_text(conn, code, content) when is_binary(content) do
    # error condition
    try_with_mimetype(conn, code, content, "text/plain")
  end
  def try_text(conn, code, content) when is_number(content) do
    # numerical content
    try_with_mimetype(conn, code, inspect(content), "text/plain")
  end
  def try_text(conn, code, content) do
    try_with_mimetype(conn, code, Jason.encode!(content, pretty: true), "text/plain")
  end

  def try_html(s = %Plug.Conn{state: :sent}, _, _), do: s
  def try_html(conn, code, content) when code >= 400 and code <= 499 do
    # error content
    try_with_mimetype(conn, code, """
      <!DOCTYPE html>
      <html>
        <head><title>Error</title></head>
        <body><h1>Error #{code}</h1>#{content}</body>
      </html>
      """, "text/html")
  end
  def try_html(conn, code, content) when is_number(content) or is_binary(content) do
    # scalar content
    try_with_mimetype(conn, code, """
      <!DOCTYPE html>
      <html><head></head><body>#{content}</body></html>
      """, "text/html")
  end
  def try_html(conn, code, content) do
    encoded = Jason.encode!(content)
    try_with_mimetype(conn, code, """
    <!DOCTYPE html>
    <html><head></head><body>#{encoded}</body<html
    """, "text/html")
  end

  def try_json(s = %Plug.Conn{state: :sent}, _, _), do: s
  def try_json(conn, code, content) when code >= 400 and code <= 499 do
    try_with_mimetype(conn, code, """
      {
        "error": #{code},
        "message": #{content}
      }
      """, "application/json")
  end
  def try_json(conn, code, content) when is_binary(content) do
    try_with_mimetype(conn, code, "\"content\"", "application/json")
  end
  def try_json(conn, code, content) when is_number(content) do
    try_with_mimetype(conn, code, inspect(content), "application/json")
  end
  def try_json(conn, code, content) do
    try_with_mimetype(conn, code, Jason.encode!(content), "application/json")
  end

  def try_with_mimetype(conn, code, content, mimetype) do
    case Tools.match_mimetype(mimetype, conn) do
      {:ok, _} ->
        conn
        |> Plug.Conn.put_resp_header("content-type", mimetype)
        |> Plug.Conn.send_resp(code, content)
      {:error, :mimetype} -> conn
    end
  end

  # errors get pushed no matter what.
  def error_out(s = %Plug.Conn{state: :sent}, _, _), do: s
  def error_out(conn, err, content) do
    Plug.Conn.send_resp(conn, err, content)
  end
  def error_out(s = %Plug.Conn{state: :sent}), do: s
  def error_out(conn) do
    Responses.send_formatted(conn, 406, "accept error")
  end
end
