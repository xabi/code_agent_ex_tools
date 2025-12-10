defmodule CodeAgentExTools.MixProject do
  use Mix.Project

  def project do
    [
      app: :code_agent_ex_tools,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Python integration for tools
      {:pythonx, "~> 0.4"},

      # HTTP client for API calls
      {:req, "~> 0.5"}
    ]
  end
end
