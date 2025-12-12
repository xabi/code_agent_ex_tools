defmodule CodeAgentExTools.PythonTools do
  @moduledoc """
  Tools for executing Python code in CodeAgent.

  Provides a python_interpreter tool that can execute Python code
  and return results, including images from matplotlib.
  """

  # TODO: Handle image results with {:image, path} tuples
  require Logger

  @doc """
  Safe stdlib imports allowed by default.
  """
  def safe_stdlib_imports do
    [
      "math",
      "statistics",
      "decimal",
      "fractions",
      "random",
      "datetime",
      "time",
      "calendar",
      "collections",
      "itertools",
      "functools",
      "string",
      "textwrap",
      "re",
      "json",
      "csv",
      "io",
      "base64"
    ]
  end

  @doc """
  Returns the python_interpreter tool for CodeAgent.

  ## Options

  - `:allowed_imports` - List of allowed Python modules (nil = all allowed)
  - `:output_dir` - Directory where generated files should be saved (default: "/tmp/code_agent")
  """
  def python_interpreter(opts \\ []) do
    allowed_imports = Keyword.get(opts, :allowed_imports)
    output_dir = Keyword.get(opts, :output_dir, "/tmp/code_agent")

    # Ensure output directory exists
    File.mkdir_p!(output_dir)

    %{
      name: :python_interpreter,
      description: """
      Execute Python code and return the result.
      IMPORTANT: Set a 'result' variable with the value to return. Do NOT use print().
      Example: result = 2 + 2  # returns "4"

      For matplotlib plots or image/video/audio generation:
      - Use OUTPUT_DIR variable to save files (automatically set to '#{output_dir}')
      - Set 'result' to a tuple: ("image", path) or ("video", path) or ("audio", path)
      - Example:
        import matplotlib.pyplot as plt
        import os
        plt.plot([1,2,3])
        path = os.path.join(OUTPUT_DIR, 'plot.png')
        plt.savefig(path)
        result = ("image", path)  # This will display the image
      """,
      inputs: %{
        "code" => %{
          type: "string",
          description:
            "Python code to execute. Must set 'result' variable (not print). Example: result = sum([1,2,3])"
        }
      },
      output_type: "string",
      safety: :unsafe,
      function: fn code ->
        code = normalize_arg(code)
        execute_python(code, allowed_imports, output_dir)
      end
    }
  end

  @doc """
  Returns all Python tools for CodeAgent.
  """
  def all_tools(opts \\ []) do
    [python_interpreter(opts)]
  end

  # Execute Python code
  defp execute_python(code, allowed_imports, output_dir) do
    Logger.info("[PythonTools] Executing Python code (#{String.length(code)} chars)")

    case validate_imports(code, allowed_imports) do
      :ok ->
        try do
          # Indent user code
          indented_code =
            code |> String.split("\n") |> Enum.map(&("    " <> &1)) |> Enum.join("\n")

          wrapped_code = """
          import os
          # Set OUTPUT_DIR environment variable for user code
          OUTPUT_DIR = '#{output_dir}'
          os.environ['OUTPUT_DIR'] = OUTPUT_DIR

          try:
              # User code
          #{indented_code}

              # Return result (can be a tuple like ("image", path) or a simple value)
              if 'result' in globals():
                  output = ("ok", result)
              else:
                  output = ("ok", "Execution completed successfully")
          except Exception as e:
              import traceback
              error_details = traceback.format_exc()
              output = ("error", f"{type(e).__name__}: {str(e)}\\n\\nTraceback:\\n{error_details}")

          output
          """

          {result, _globals} = Pythonx.eval(wrapped_code, %{})
          decoded_result = Pythonx.decode(result)

          case decoded_result do
            {"ok", {"image", path}} ->
              Logger.info("[PythonTools] Execution successful with image: #{path}")
              # Return tuple that LLMFormattable can detect as an image
              {:image, path}

            {"ok", {"video", path}} ->
              Logger.info("[PythonTools] Execution successful with video: #{path}")
              {:video, path}

            {"ok", {"audio", path}} ->
              Logger.info("[PythonTools] Execution successful with audio: #{path}")
              {:audio, path}

            {"ok", message} ->
              Logger.info("[PythonTools] Execution successful")
              to_string(message)

            {"error", error_msg} ->
              Logger.error("[PythonTools] Python error: #{error_msg}")
              "Error: #{error_msg}"

            other ->
              inspect(other)
          end
        rescue
          error ->
            Logger.error("[PythonTools] Exception: #{inspect(error)}")
            "Execution error: #{inspect(error)}"
        end

      {:error, unauthorized_imports} ->
        "Unauthorized imports: #{Enum.join(unauthorized_imports, ", ")}"
    end
  end

  # Normalize charlist to binary
  defp normalize_arg(arg) when is_list(arg) do
    # Check if it's a keyword list with :code key
    if Keyword.keyword?(arg) and Keyword.has_key?(arg, :code) do
      Keyword.get(arg, :code)
    else
      # It's a charlist, convert to string
      List.to_string(arg)
    end
  end

  defp normalize_arg(arg) when is_map(arg), do: Map.get(arg, "code", "")
  defp normalize_arg(arg), do: arg

  # Validate imports
  defp validate_imports(_code, nil), do: :ok

  defp validate_imports(code, allowed_imports) when is_list(allowed_imports) do
    detected_imports = extract_imports(code)

    unauthorized =
      Enum.reject(detected_imports, fn import_name ->
        Enum.any?(allowed_imports, fn allowed ->
          import_name == allowed or String.starts_with?(import_name, "#{allowed}.")
        end)
      end)

    if length(unauthorized) > 0 do
      {:error, unauthorized}
    else
      :ok
    end
  end

  # Extract imports from Python code
  defp extract_imports(code) do
    patterns = [
      ~r/^\s*import\s+([a-zA-Z_][a-zA-Z0-9_\.]*)/m,
      ~r/^\s*import\s+([a-zA-Z_][a-zA-Z0-9_\.]*)\s+as\s+/m,
      ~r/^\s*from\s+([a-zA-Z_][a-zA-Z0-9_\.]*)\s+import\s+/m
    ]

    patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, code)
      |> Enum.map(fn [_full, module_name] -> module_name end)
    end)
    |> Enum.uniq()
  end
end
