defmodule ExDicom.Parser.DicomDataSet do
  @moduledoc """
  Internal helper functions for parsing implicit and explicit DICOM data sets.
  """

  alias ExDicom.Reader.ReadDicomElement
  alias ExDicom.ByteStream

  @doc """
  Reads an explicit data set.

  ## Parameters
    * dataset - The dataset to store elements in
    * byte_stream - The byte stream to read from
    * max_position - The maximum position to read up to (optional)
    * opts - Options map with optional keys:
      * :until_tag - Stop reading when this tag is encountered
  """
  def parse_explicit(dataset, byte_stream, max_position \\ nil, opts \\ %{}) do
    max_position = max_position || ByteStream.get_size(byte_stream)

    cond do
      is_nil(byte_stream) ->
        {:error, "parse_explicit: missing required parameter 'byteStream'"}

      max_position < byte_stream.position or max_position > ByteStream.get_size(byte_stream) ->
        {:error, "parse_explicit: invalid value for parameter 'maxPosition'"}

      true ->
        do_parse_explicit(dataset, byte_stream, max_position, opts)
    end
  end

  @doc """
  Reads an implicit data set.

  ## Parameters
    * dataset - The dataset to store elements in
    * byte_stream - The byte stream to read from
    * max_position - The maximum position to read up to (optional)
    * opts - Options map with optional keys:
      * :until_tag - Stop reading when this tag is encountered
      * :vr_callback - Function to determine VR for private tags
  """
  def parse_implicit(dataset, byte_stream, max_position \\ nil, opts \\ %{}) do
    max_position = max_position || ByteStream.get_size(byte_stream)

    cond do
      is_nil(byte_stream) ->
        {:error, "parse_implicit: missing required parameter 'byteStream'"}

      max_position < byte_stream.position or max_position > ByteStream.get_size(byte_stream) ->
        {:error, "parse_implicit: invalid value for parameter 'maxPosition'"}

      true ->
        do_parse_implicit(dataset, byte_stream, max_position, opts)
    end
  end

  defp do_parse_explicit(dataset, byte_stream, max_position, opts) do
    parse_loop(
      dataset,
      byte_stream,
      max_position,
      opts,
      &ReadDicomElement.read_dicom_element_explicit/3
    )
  end

  defp do_parse_implicit(dataset, byte_stream, max_position, opts) do
    parse_loop(
      dataset,
      byte_stream,
      max_position,
      opts,
      &ReadDicomElement.read_dicom_element_implicit/3
    )
  end

  defp parse_loop(dataset, byte_stream, max_position, opts, read_fn) do
    remaining_bytes = max_position - byte_stream.position

    cond do
      # Already at or past max position
      byte_stream.position >= max_position ->
        {:ok, dataset}

      # Not enough bytes left for a minimal DICOM element (tag + VR + length = 8 bytes)
      remaining_bytes < 8 ->
        # Add warning about trailing bytes if any remain
        final_dataset =
          if remaining_bytes > 0 do
            warnings = dataset.warnings ++ ["#{remaining_bytes} trailing bytes at end of dataset"]
            %{dataset | warnings: warnings}
          else
            dataset
          end

        {:ok, final_dataset}

      # Enough bytes remain to try reading an element
      true ->
        case read_fn.(byte_stream, dataset.warnings, opts[:until_tag]) do
          {:ok, element, updated_stream, warnings} ->
            # Update dataset with new element and warnings
            updated_dataset = %{
              dataset
              | elements: Map.put(dataset.elements, element.tag, element),
                warnings: warnings
            }

            if element.tag == opts[:until_tag] do
              {:ok, updated_dataset}
            else
              # Continue parsing
              parse_loop(updated_dataset, updated_stream, max_position, opts, read_fn)
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end
end
