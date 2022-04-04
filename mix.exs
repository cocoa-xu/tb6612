defmodule Cirlute.TB6612.MixProject do
  use Mix.Project

  def project do
    [
      app: :cirlute_tb6612,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:circuits_gpio, "~> 1.0"},
      {:cirlute_motor, "~> 0.1.0", github: "cocoa-xu/motor"}
    ]
  end
end
