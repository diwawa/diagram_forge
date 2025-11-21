defmodule DiagramForge.Diagrams.DocumentIngestor do
  @moduledoc """
  Handles text extraction from documents and chunking for LLM processing.
  """

  alias DiagramForge.Diagrams.Document

  @doc """
  Extracts text from a document based on its source type.

  For PDFs, uses the `pdftotext` command-line tool.
  For Markdown, reads the file directly.

  Returns `{:ok, text}` on success or `{:error, reason}` on failure.
  """
  def extract_text(%Document{source_type: :markdown, path: path}) do
    case File.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> {:error, "Failed to read markdown file: #{inspect(reason)}"}
    end
  end

  def extract_text(%Document{source_type: :pdf, path: path}) do
    tmp_txt = Path.join(System.tmp_dir!(), "#{Path.basename(path)}.txt")

    try do
      case System.cmd("pdftotext", ["-layout", path, tmp_txt]) do
        {_, 0} ->
          case File.read(tmp_txt) do
            {:ok, text} ->
              File.rm(tmp_txt)
              {:ok, text}

            {:error, reason} ->
              {:error, "Failed to read extracted PDF text: #{inspect(reason)}"}
          end

        {error_output, exit_code} ->
          {:error, "pdftotext failed with exit code #{exit_code}: #{error_output}"}
      end
    rescue
      e in ErlangError ->
        {:error, "pdftotext command failed: #{inspect(e.original)}"}
    end
  end

  @doc """
  Chunks text into overlapping segments for LLM processing.

  ## Options

    * `:chunk_size` - Maximum characters per chunk (default: 4000)
    * `:overlap` - Number of characters to overlap between chunks (default: 500)

  ## Examples

      iex> text = "paragraph 1\\n\\nparagraph 2\\n\\nparagraph 3"
      iex> DiagramForge.Diagrams.DocumentIngestor.chunk_text(text, chunk_size: 50, overlap: 10)
      # Returns a list of overlapping text chunks

  """
  def chunk_text(text, opts \\ [])

  def chunk_text(nil, _opts), do: []
  def chunk_text("", _opts), do: []

  def chunk_text(text, opts) do
    chunk_size = opts[:chunk_size] || 4000
    overlap = opts[:overlap] || 500

    text
    |> String.split(~r/\n{2,}/)
    |> Enum.reduce({[], ""}, fn para, {chunks, current} ->
      candidate =
        if current == "" do
          para
        else
          current <> "\n\n" <> para
        end

      if String.length(candidate) >= chunk_size do
        new_chunks = [candidate | chunks]
        new_current = String.slice(candidate, -overlap, overlap)
        {new_chunks, new_current}
      else
        {chunks, candidate}
      end
    end)
    |> then(fn {chunks, last} ->
      chunks =
        if String.trim(last) != "" do
          [last | chunks]
        else
          chunks
        end

      Enum.reverse(chunks)
    end)
  end
end
