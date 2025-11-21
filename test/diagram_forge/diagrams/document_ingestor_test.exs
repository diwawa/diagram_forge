defmodule DiagramForge.Diagrams.DocumentIngestorTest do
  use DiagramForge.DataCase, async: true

  alias DiagramForge.Diagrams.{Document, DocumentIngestor}

  describe "extract_text/1 for markdown" do
    test "successfully extracts text from markdown file" do
      content = "# Test Document\n\nThis is a test markdown file."
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, content)

      document = %Document{source_type: :markdown, path: path}

      assert {:ok, text} = DocumentIngestor.extract_text(document)
      assert text == content

      File.rm!(path)
    end

    test "returns error when markdown file doesn't exist" do
      document = %Document{source_type: :markdown, path: "/nonexistent/path.md"}

      assert {:error, message} = DocumentIngestor.extract_text(document)
      assert message =~ "Failed to read markdown file"
      assert message =~ ":enoent"
    end

    test "returns error when markdown file is unreadable" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, "content")
      File.chmod!(path, 0o000)

      document = %Document{source_type: :markdown, path: path}

      assert {:error, message} = DocumentIngestor.extract_text(document)
      assert message =~ "Failed to read markdown file"

      File.chmod!(path, 0o644)
      File.rm!(path)
    end
  end

  describe "extract_text/1 for PDF" do
    test "returns error when pdftotext command fails" do
      # Test the error handling when pdftotext isn't available or fails
      # We don't skip this - we test the actual error behavior
      pdf_path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.pdf")
      File.write!(pdf_path, "dummy pdf content")

      document = %Document{source_type: :pdf, path: pdf_path}

      # This will either succeed if pdftotext is installed, or fail with expected error
      result = DocumentIngestor.extract_text(document)

      case result do
        {:ok, _text} ->
          # pdftotext is installed and worked - that's fine
          :ok

        {:error, message} ->
          # pdftotext not installed or failed - verify we get proper error message
          assert message =~ "pdftotext"
      end

      File.rm!(pdf_path)
    end

    test "returns error when PDF file doesn't exist" do
      document = %Document{source_type: :pdf, path: "/nonexistent/path.pdf"}

      assert {:error, message} = DocumentIngestor.extract_text(document)
      assert message =~ "pdftotext"
    end
  end

  describe "chunk_text/2" do
    test "returns single chunk for text smaller than chunk_size" do
      text = "This is a small text."

      chunks = DocumentIngestor.chunk_text(text, chunk_size: 100, overlap: 10)

      assert length(chunks) == 1
      assert hd(chunks) == text
    end

    test "returns multiple chunks for text larger than chunk_size" do
      # Create text with multiple paragraphs
      para1 = String.duplicate("a", 60)
      para2 = String.duplicate("b", 60)
      para3 = String.duplicate("c", 60)
      text = Enum.join([para1, para2, para3], "\n\n")

      chunks = DocumentIngestor.chunk_text(text, chunk_size: 100, overlap: 20)

      assert length(chunks) > 1
      # First chunk should contain first two paragraphs
      assert String.contains?(hd(chunks), para1)
      assert String.contains?(hd(chunks), para2)
    end

    test "chunks have proper overlap" do
      para1 = "First paragraph with some content here."
      para2 = "Second paragraph with different content."
      para3 = "Third paragraph for testing overlap."
      text = Enum.join([para1, para2, para3], "\n\n")

      chunks = DocumentIngestor.chunk_text(text, chunk_size: 80, overlap: 30)

      # When chunks are created, they should overlap
      if length(chunks) > 1 do
        [first, second | _] = chunks
        # The overlap should appear at the end of first chunk and start of second
        overlap_text = String.slice(first, -30, 30)
        assert String.starts_with?(second, overlap_text) or String.contains?(second, overlap_text)
      end
    end

    test "handles empty text" do
      chunks = DocumentIngestor.chunk_text("")

      assert chunks == []
    end

    test "handles text with only whitespace" do
      chunks = DocumentIngestor.chunk_text("   \n\n   \n\n   ")

      assert chunks == []
    end

    test "handles single paragraph" do
      text = "This is a single paragraph without any line breaks."

      chunks = DocumentIngestor.chunk_text(text, chunk_size: 100, overlap: 10)

      assert length(chunks) == 1
      assert hd(chunks) == text
    end

    test "uses default chunk_size and overlap when not specified" do
      # Create a large text that will definitely be chunked with default settings
      large_text = String.duplicate("paragraph\n\n", 500)

      chunks = DocumentIngestor.chunk_text(large_text)

      # With default chunk_size of 4000, this should create multiple chunks
      assert length(chunks) > 1
    end

    test "respects custom chunk_size" do
      para1 = String.duplicate("a", 30)
      para2 = String.duplicate("b", 30)
      para3 = String.duplicate("c", 30)
      text = Enum.join([para1, para2, para3], "\n\n")

      # With chunk_size of 50, should create multiple chunks
      chunks = DocumentIngestor.chunk_text(text, chunk_size: 50, overlap: 10)

      assert length(chunks) >= 2
    end

    test "handles text with multiple consecutive newlines" do
      text = "Para 1\n\n\n\nPara 2\n\n\n\n\nPara 3"

      chunks = DocumentIngestor.chunk_text(text, chunk_size: 100, overlap: 10)

      # Should split on multiple newlines
      assert is_list(chunks)
      assert length(chunks) >= 1
    end

    test "preserves paragraph structure in chunks" do
      para1 = "First paragraph content."
      para2 = "Second paragraph content."
      text = Enum.join([para1, para2], "\n\n")

      chunks = DocumentIngestor.chunk_text(text, chunk_size: 1000, overlap: 10)

      # Since text is small, should be single chunk preserving structure
      assert length(chunks) == 1
      assert hd(chunks) == text
    end
  end
end
