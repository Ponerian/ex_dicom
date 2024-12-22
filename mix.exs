defmodule ExDicom.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_dicom,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "EX_DICOM",
      source_url: "https://github.com/ponerian/ex_dicom",
      docs: docs()
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [
      main: "ExDicom",
      extras: ["README.md"]
    ]
  end
end
