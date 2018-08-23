defmodule Exaggerate.Mixfile do
  use Mix.Project

  def project do
    Application.put_env(:exaggerate, :real_root, File.cwd!)
    [
      app: :exaggerate,
      version: "0.1.0",
      elixir: "~> 1.6-dev",
      start_permanent: Mix.env == :prod,
      deps: deps(),
    ]
  end

  def application do
    [ extra_applications: [:logger] ]
  end

  defp deps do
    [
      {:exonerate, git: "https://github.com/rstorsauce/exonerate.git"},
      {:poison, "~> 3.1"},
      {:plug, "~> 1.4"},
    ]
  end
end
