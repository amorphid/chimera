defmodule Chimera.MixProject do
  use Mix.Project

  def project do
    [
      app: :chimera,
      version: version(),
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :ssl],
      mod: {Chimera.Application, start_args()}
    ]
  end

  defp deps do
    [
      {:janky_bench, "~> 0.1", only: :dev},
      {:json_momoa, "~> 0.1"}
    ]
  end

  defp start_args() do
    %{
      chimera: %{
        version: version()
      }
    }
  end

  defp version() do
    "0.1.0"
  end
end
