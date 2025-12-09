# CodeAgentEx Tools

> Extended tools for CodeAgentEx with Python dependencies

This project contains Python-based tools for [CodeAgentEx](../code_agent_minimal), including Wikipedia search, finance data, image generation, and vision analysis.

## Features

### Wikipedia Tools
- `WikipediaTools.wikipedia_search/0` - Search Wikipedia articles
- `WikipediaTools.wikipedia_page/0` - Read full Wikipedia pages

### Finance Tools
- `FinanceTools.stock_price/0` - Get current stock prices via Yahoo Finance

### Python Tools
- `PythonTools.python_interpreter/0` - Execute arbitrary Python code

### Image Tools
- `ImageTools.text_to_image/0` - Generate images using HuggingFace Inference API
- `ImageTools.text_to_video/0` - Generate videos using HuggingFace Inference API

### Moondream Vision Tools
- `MoondreamTools.caption/0` - Generate image captions
- `MoondreamTools.query/0` - Ask questions about images
- `MoondreamTools.detect/0` - Detect objects in images
- `MoondreamTools.point/0` - Find points of interest in images

### SmolAgents Tools
- `SmolAgentsTools.flux_image/0` - Generate images with FLUX.1-schnell
- `SmolAgentsTools.web_search/0` - Search the web via DuckDuckGo

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:code_agent_ex, path: "../code_agent_minimal"},  # Core library
    {:code_agent_ex_tools, path: "../code_agent_ex_tools"}  # This package
  ]
end
```

## Python Dependencies

Initialize Python environment at application startup:

```elixir
# In your application.ex
def start(_type, _args) do
  # Initialize Python with default dependencies
  CodeAgentExTools.PythonEnv.init()

  children = [
    # Your supervisors...
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Default Python packages installed:
- `wikipedia==1.4.0` - Wikipedia API
- `markdownify>=0.11.6` - HTML to Markdown converter
- `yfinance>=0.2.0` - Yahoo Finance data
- `matplotlib>=3.7.0` - Plotting library
- `smolagents>=0.1.0` - HuggingFace agents
- `huggingface_hub>=0.36.0` - HuggingFace API
- `gradio_client>=0.10.0` - Gradio client
- `ddgs>=1.0.0` - DuckDuckGo search

## Usage with CodeAgentEx

Tools from this project return plain maps compatible with `CodeAgentEx.Tool`:

```elixir
alias CodeAgentEx.{CodeAgent, AgentConfig, Tool}
alias CodeAgentExTools.WikipediaTools

# Get tool maps
wiki_tool_maps = WikipediaTools.all_tools()

# Convert to CodeAgentEx.Tool structs
tools = Enum.map(wiki_tool_maps, &struct!(Tool, &1))

# Use with agent
config = AgentConfig.new(
  tools: tools,
  max_steps: 5
)

CodeAgent.run("Search Wikipedia for Elixir programming language", config)
```

## Tool Structure

All tools return maps with these keys:

```elixir
%{
  name: :tool_name,              # atom
  description: "What it does",   # string
  inputs: %{                      # map of input specs
    "param" => %{type: "string", description: "..."}
  },
  output_type: "string",          # string
  function: fn args -> ... end   # function
}
```

These maps are compatible with `CodeAgentEx.Tool` struct:

```elixir
tool_map = WikipediaTools.wikipedia_search()
tool_struct = struct!(CodeAgentEx.Tool, tool_map)
```

## Environment Variables

Some tools require API keys:

```bash
export HF_TOKEN=hf_your_token_here          # For HuggingFace tools
export MOONDREAM_API_KEY=your_key_here      # For Moondream vision tools
```

## Dependencies

```elixir
# Required
{:pythonx, "~> 0.4"}  # Python integration
{:req, "~> 0.5"}      # HTTP client
```

## Development

```bash
cd code_agent_ex_tools
mix deps.get
mix compile
```

## Architecture

This project is designed as a **separate package** from the core `code_agent_ex` library to keep the core lightweight. Install only if you need Python-based tools.

**Core library** (`code_agent_ex`):
- Pure Elixir
- No Python dependencies
- Minimal dependencies (instructor_lite, req, jason)

**Tools library** (`code_agent_ex_tools`):
- Python integration via pythonx
- Heavy dependencies (matplotlib, yfinance, etc.)
- Optional - install only when needed

## License

MIT

## Related Projects

- [code_agent_ex](../code_agent_minimal) - Core library
- [smolagents](https://github.com/huggingface/smolagents) - Inspiration for some tools
