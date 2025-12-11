defmodule CodeAgentExTools.ImageTools do
  @moduledoc """
  Image and video generation tools for CodeAgent.

  Returns tuples like {:image, path} and {:video, path} to indicate
  generated media files.
  """

  require Logger

  @output_dir "/tmp/code_agent"

  # Ensure output directory exists
  def ensure_output_dir do
    File.mkdir_p!(@output_dir)
    @output_dir
  end

  @doc """
  Tool pour générer une vidéo depuis un texte avec l'API Hugging Face Inference.
  """
  def text_to_video(opts \\ []) do
    model = Keyword.get(opts, :model, "Wan-AI/Wan2.1-T2V-14B")

    %{
      name: :text_to_video,
      description: """
      Generates a video from a text prompt using Hugging Face Inference API.
      Requires HF_TOKEN environment variable to be set.

      Usage:
        tools.text_to_video.("a cat walking on a sunny beach, photorealistic")

      The generated video will be saved in /tmp/code_agent/ and the function returns a tuple
      {:video, path} where path points to the saved MP4 file.

      Tips for better results:
      - Be descriptive and specific in your prompt
      - Mention camera movements like "camera panning", "slow motion"
      - Include style hints and lighting details
      """,
      inputs: %{
        "prompt" => %{type: "string", description: "Text description of the video to generate"}
      },
      output_type: "tuple",
      safety: :unsafe,
      function: fn prompt ->
        do_text_to_video_single_arg(prompt, model)
      end
    }
  end

  # Single argument handler - accepts just prompt as string
  defp do_text_to_video_single_arg(prompt, model) when is_binary(prompt) do
    do_text_to_video(prompt, %{}, model)
  end

  # If it's a charlist, convert it
  defp do_text_to_video_single_arg(prompt, model) when is_list(prompt) do
    prompt = to_string(prompt)
    do_text_to_video(prompt, %{}, model)
  rescue
    _ -> "Error: Could not convert prompt to string"
  end

  # Fallback
  defp do_text_to_video_single_arg(_prompt, _model) do
    "Error: Prompt must be a string"
  end

  defp do_text_to_video(prompt, _options, model) when is_binary(prompt) do
    token = System.get_env("HF_TOKEN")

    if is_nil(token) do
      "Error: HF_TOKEN environment variable not set. Get your token at https://huggingface.co/settings/tokens"
    else
      Logger.info("[ImageTools] Generating video with prompt: #{String.slice(prompt, 0, 50)}...")

      # Use Python with huggingface_hub library
      python_code = """
      import os
      from huggingface_hub import InferenceClient
      import base64

      try:
          # Convert bytes to str if needed
          prompt_str = prompt_text.decode('utf-8') if isinstance(prompt_text, bytes) else prompt_text
          model_str = model_name.decode('utf-8') if isinstance(model_name, bytes) else model_name

          client = InferenceClient(
              provider="replicate",
              api_key=os.environ.get("HF_TOKEN")
          )

          # Generate video - returns video bytes
          video_bytes = client.text_to_video(
              prompt_str,
              model=model_str
          )

          # Convert to base64
          video_base64 = base64.b64encode(video_bytes).decode('utf-8')

          output = ("ok", video_base64)
      except Exception as e:
          import traceback
          output = ("error", f"{str(e)}\\n\\nTraceback:\\n{traceback.format_exc()}")

      output
      """

      try do
        {result, _globals} =
          Pythonx.eval(python_code, %{
            "prompt_text" => prompt,
            "model_name" => model
          })

        case Pythonx.decode(result) do
          {"ok", video_base64} when is_binary(video_base64) ->
            case Base.decode64(video_base64) do
              {:ok, video_binary} ->
                # Save video to file
                output_dir = ensure_output_dir()
                timestamp = :os.system_time(:millisecond)
                filename = "video_#{timestamp}.mp4"
                path = Path.join(output_dir, filename)

                case File.write(path, video_binary) do
                  :ok ->
                    Logger.info("[ImageTools] ✅ Video generated successfully: #{path}")
                    {:video, path}

                  {:error, reason} ->
                    "Error saving video: #{reason}"
                end

              :error ->
                "Error: Failed to decode base64 video data"
            end

          {"error", error_msg} ->
            Logger.error("[ImageTools] Python error: #{error_msg}")
            "Error generating video: #{error_msg}"

          other ->
            "Unexpected result: #{inspect(other)}"
        end
      rescue
        error ->
          Logger.error("[ImageTools] Pythonx error: #{inspect(error)}")
          "Error: Failed to execute Python code - #{inspect(error)}"
      end
    end
  end

  @doc """
  Tool pour générer une image depuis un texte avec l'API Hugging Face Inference.
  """
  def text_to_image(opts \\ []) do
    model = Keyword.get(opts, :model, "black-forest-labs/FLUX.1-dev")

    %{
      name: :text_to_image,
      description: """
      Generates an image from a text prompt using Hugging Face Inference API.
      Requires HF_TOKEN environment variable to be set.

      Usage:
        tools.text_to_image.("a cute orange cat sitting on a sunny windowsill, photorealistic, warm tone")

      The generated image will be saved in /tmp/code_agent/ and the function returns a tuple
      {:image, path} where path points to the saved PNG file.

      Tips for better results:
      - Be descriptive and specific in your prompt
      - Include style hints like "photorealistic", "artistic", "detailed"
      - Mention lighting, mood, and composition
      """,
      inputs: %{
        "prompt" => %{type: "string", description: "Text description of the image to generate"}
      },
      output_type: "tuple",
      safety: :unsafe,
      function: fn prompt ->
        do_text_to_image_single_arg(prompt, model)
      end
    }
  end

  # Single argument handler - accepts just prompt as string
  defp do_text_to_image_single_arg(prompt, model) when is_binary(prompt) do
    do_text_to_image(prompt, %{}, model)
  end

  # If it's a charlist, convert it
  defp do_text_to_image_single_arg(prompt, model) when is_list(prompt) do
    prompt = to_string(prompt)
    do_text_to_image(prompt, %{}, model)
  rescue
    _ -> "Error: Could not convert prompt to string"
  end

  # Fallback
  defp do_text_to_image_single_arg(_prompt, _model) do
    "Error: Prompt must be a string"
  end

  defp do_text_to_image(prompt, _options, model) when is_binary(prompt) do
    token = System.get_env("HF_TOKEN")

    if is_nil(token) do
      "Error: HF_TOKEN environment variable not set. Get your token at https://huggingface.co/settings/tokens"
    else
      Logger.info("[ImageTools] Generating image with prompt: #{String.slice(prompt, 0, 50)}...")

      # Use Python with huggingface_hub library
      python_code = """
      import os
      from huggingface_hub import InferenceClient
      from io import BytesIO
      import base64

      try:
          # Convert bytes to str if needed
          prompt_str = prompt_text.decode('utf-8') if isinstance(prompt_text, bytes) else prompt_text
          model_str = model_name.decode('utf-8') if isinstance(model_name, bytes) else model_name

          client = InferenceClient(
              provider="replicate",
              api_key=os.environ.get("HF_TOKEN")
          )

          # Generate image - returns a PIL.Image object
          image = client.text_to_image(
              prompt_str,
              model=model_str
          )

          # Convert PIL Image to base64
          buffer = BytesIO()
          image.save(buffer, format='PNG')
          img_bytes = buffer.getvalue()
          image_base64 = base64.b64encode(img_bytes).decode('utf-8')

          output = ("ok", image_base64)
      except Exception as e:
          import traceback
          output = ("error", f"{str(e)}\\n\\nTraceback:\\n{traceback.format_exc()}")

      output
      """

      try do
        {result, _globals} =
          Pythonx.eval(python_code, %{
            "prompt_text" => prompt,
            "model_name" => model
          })

        case Pythonx.decode(result) do
          {"ok", image_base64} when is_binary(image_base64) ->
            case Base.decode64(image_base64) do
              {:ok, image_binary} ->
                # Save image to file
                output_dir = ensure_output_dir()
                timestamp = :os.system_time(:millisecond)
                filename = "image_#{timestamp}.png"
                path = Path.join(output_dir, filename)

                case File.write(path, image_binary) do
                  :ok ->
                    Logger.info("[ImageTools] ✅ Image generated successfully: #{path}")
                    {:image, path}

                  {:error, reason} ->
                    "Error saving image: #{reason}"
                end

              :error ->
                "Error: Failed to decode base64 image data"
            end

          {"error", error_msg} ->
            Logger.error("[ImageTools] Python error: #{error_msg}")
            "Error generating image: #{error_msg}"

          other ->
            "Unexpected result: #{inspect(other)}"
        end
      rescue
        error ->
          Logger.error("[ImageTools] Pythonx error: #{inspect(error)}")
          "Error: Failed to execute Python code - #{inspect(error)}"
      end
    end
  end

  @doc """
  Tool to download an image from a URL.
  """
  def download_image do
    %{
      name: :download_image,
      description:
        "Downloads an image from a URL and saves it locally. Returns {:image, path}. Call with: tools.download_image.(url)",
      inputs: %{
        "url" => %{type: "string", description: "URL of the image to download"}
      },
      output_type: "tuple",
      safety: :safe,
      function: &do_download_image/1
    }
  end

  defp do_download_image(url) when is_binary(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        # Determine extension from content-type or URL
        ext = cond do
          String.ends_with?(url, ".png") -> "png"
          String.ends_with?(url, ".jpg") -> "jpg"
          String.ends_with?(url, ".jpeg") -> "jpeg"
          true -> "png"
        end

        # Save to file
        output_dir = ensure_output_dir()
        timestamp = :os.system_time(:millisecond)
        filename = "downloaded_#{timestamp}.#{ext}"
        path = Path.join(output_dir, filename)

        case File.write(path, body) do
          :ok ->
            Logger.info("[ImageTools] Image downloaded: #{path}")
            {:image, path}

          {:error, reason} ->
            "Error saving downloaded image: #{reason}"
        end

      {:ok, %{status: status}} ->
        "Error downloading image: HTTP #{status}"

      {:error, reason} ->
        "Error downloading image: #{inspect(reason)}"
    end
  end

  defp do_download_image(url) when is_list(url) do
    do_download_image(to_string(url))
  end

  @doc """
  Tool to load an image from a local file.
  """
  def load_image do
    %{
      name: :load_image,
      description:
        "Loads an image from a local file path. Returns {:image, path}. Call with: tools.load_image.(path)",
      inputs: %{
        "path" => %{type: "string", description: "Local file path of the image"}
      },
      output_type: "tuple",
      safety: :safe,
      function: &do_load_image/1
    }
  end

  defp do_load_image(path) when is_binary(path) do
    if File.exists?(path) do
      {:image, path}
    else
      "Error: File not found at #{path}"
    end
  end

  defp do_load_image(path) when is_list(path) do
    do_load_image(to_string(path))
  end

  @doc """
  Tool pour obtenir les métadonnées techniques d'une image (format, taille).
  Note: Pour obtenir une DESCRIPTION du CONTENU de l'image, utilisez moondream_caption ou moondream_query.
  """
  def image_metadata do
    %{
      name: :image_metadata,
      description:
        "Returns technical metadata about an image file (format, size in KB). Does NOT describe image content. For content description, use moondream_caption. Call with: tools.image_metadata.(image_path)",
      inputs: %{
        "image_path" => %{type: "string", description: "Path to the image file"}
      },
      safety: :safe,
      output_type: "string",
      function: &do_image_metadata/1
    }
  end

  defp do_image_metadata(path) do
    if File.exists?(path) do
      case File.stat(path) do
        {:ok, stat} ->
          format = Path.extname(path) |> String.trim_leading(".")
          size_kb = Float.round(stat.size / 1024, 2)
          "Image metadata: #{Path.basename(path)}, Format: #{format}, Size: #{size_kb} KB"

        {:error, reason} ->
          "Error getting image metadata: #{reason}"
      end
    else
      "Error: File not found at #{path}"
    end
  end

  @doc """
  Tool pour sauvegarder une image à un emplacement spécifique.
  """
  def save_image do
    %{
      name: :save_image,
      description:
        "Saves an image to a specific location. Call with: tools.save_image.(source_path, destination_path)",
      inputs: %{
        "source_path" => %{type: "string", description: "Path to the source image"},
        "destination_path" => %{type: "string", description: "Path where to save the image"}
      },
      safety: :unsafe,
      output_type: "string",
      function: fn source_path, dest_path ->
        do_save_image(source_path, dest_path)
      end
    }
  end

  defp do_save_image(source_path, dest_path) do
    case File.copy(source_path, dest_path) do
      {:ok, _bytes} -> "Image saved to #{dest_path}"
      {:error, reason} -> "Error saving image: #{reason}"
    end
  end

  @doc """
  Retourne tous les tools image/video + final_answer.
  """
  def all_tools(opts \\ []) do
    [
      text_to_image(opts),
      text_to_video(opts),
      download_image(),
      load_image(),
      image_metadata(),
      save_image(),
    ]
  end
end
