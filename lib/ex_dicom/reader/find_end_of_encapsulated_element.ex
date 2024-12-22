defmodule ExDicom.Reader.FindEndOfEncapsulatedElement do
  @moduledoc """
  Internal helper functions for parsing encapsulated DICOM pixel data elements.
  Handles reading and managing fragments of encapsulated pixel data.
  """

  alias ExDicom.ByteStream
  alias ExDicom.Reader.ReadTag

  @sequence_delimiter_tag "xfffee0dd"
  @item_tag "xfffee000"

  @typedoc """
  Type representing a pixel data fragment
  """
  @type fragment :: %{
          offset: non_neg_integer(),
          position: non_neg_integer(),
          length: non_neg_integer()
        }

  @doc """
  Reads an encapsulated pixel data element and adds an array of fragments to the element
  containing the offset and length of each fragment and any offsets from the basic offset
  table.

  ## Parameters

    * byte_stream - The byte stream to read from
    * element - The element to add fragment information to
    * warnings - List to collect any warnings during parsing

  ## Returns

    The modified element with fragment information added

  ## Raises

    * RuntimeError if required parameters are missing or if basic offset table is not found
  """
  # Success case
  @spec find(byte_stream :: ByteStream.t(), element :: map(), warnings :: list()) ::
          {:ok, map(), ByteStream.t(), list()}
          # Error case
          | {:error, String.t()}

  def find(nil, _element, _warnings) do
    {:error,
     "ExDicom.Reader.FindEndOfEncapsulatedElement.find: missing required parameter 'byte_stream'"}
  end

  def find(_byte_stream, nil, _warnings) do
    {:error,
     "ExDicom.Reader.FindEndOfEncapsulatedElement.find: missing required parameter 'element'"}
  end

  def find(%ByteStream{} = byte_stream, element, warnings) do
    # Initialize element with encapsulated pixel data properties
    element =
      element
      |> Map.put(:encapsulated_pixel_data, true)
      |> Map.put(:basic_offset_table, [])
      |> Map.put(:fragments, [])

    # Read and validate basic offset table
    case ReadTag.read_tag(byte_stream) do
      {:ok, @item_tag, stream} ->
        {element, final_stream, final_warnings} =
          read_basic_offset_table(stream, element)
          |> read_fragments(stream, warnings)

        # Ensure we return the correct tuple format
        {:ok, element, final_stream, final_warnings}

      {:ok, other_tag, _} ->
        {:error,
         "ExDicom.Reader.FindEndOfEncapsulatedElement: basic offset table not found, got tag: #{inspect(other_tag)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Reads the basic offset table and adds offsets to the element
  @spec read_basic_offset_table(byte_stream :: ByteStream.t(), element :: map()) :: map()
  defp read_basic_offset_table(%ByteStream{} = byte_stream, element) do
    case ByteStream.read_uint32(byte_stream) do
      {:ok, basic_offset_table_length, updated_stream} ->
        num_fragments = div(basic_offset_table_length, 4)

        {basic_offset_table, _final_stream} =
          Enum.reduce(1..num_fragments, {[], updated_stream}, fn _i, {offsets, stream} ->
            {:ok, offset, stream} = ByteStream.read_uint32(stream)
            {offsets ++ [offset], stream}
          end)

        %{element | basic_offset_table: basic_offset_table}

      {:error, reason} ->
        raise "Failed to read basic offset table length: #{reason}"
    end
  end

  # Reads fragments until sequence delimiter or end of stream is reached
  @spec read_fragments(element :: map(), byte_stream :: ByteStream.t(), warnings :: list()) ::
          {map(), ByteStream.t(), list()}
  defp read_fragments(element, %ByteStream{} = byte_stream, warnings) do
    base_offset = byte_stream.position
    read_fragments_loop(element, byte_stream, warnings, base_offset)
  end

  defp read_fragments_loop(element, %ByteStream{} = byte_stream, warnings, base_offset) do
    if byte_stream.position >= byte_stream.byte_array.length do
      updated_warnings =
        add_warning(
          warnings,
          "pixel data element #{element.tag} missing sequence delimiter tag #{@sequence_delimiter_tag}"
        )

      {element, byte_stream, updated_warnings}
    else
      {:ok, tag, read_byte_stream} = ReadTag.read_tag(byte_stream)
      {:ok, length, read_uint32_byte_stream} = ByteStream.read_uint32(read_byte_stream)

      case tag do
        @sequence_delimiter_tag ->
          {:ok, new_byte_stream} = ByteStream.seek(read_uint32_byte_stream, length)
          updated_element = %{element | length: new_byte_stream.position - element.data_offset}
          {updated_element, new_byte_stream, warnings}

        @item_tag ->
          fragment = %{
            offset: read_uint32_byte_stream.position - base_offset - 8,
            position: read_uint32_byte_stream.position,
            length: length
          }

          updated_element = update_in(element.fragments, &(&1 ++ [fragment]))
          {:ok, new_byte_stream} = ByteStream.seek(read_uint32_byte_stream, length)
          read_fragments_loop(updated_element, new_byte_stream, warnings, base_offset)

        unexpected_tag ->
          handle_unexpected_tag(
            element,
            read_uint32_byte_stream,
            warnings,
            base_offset,
            unexpected_tag,
            length
          )
      end
    end
  end

  # Handles unexpected tags during fragment reading
  defp handle_unexpected_tag(element, byte_stream, warnings, base_offset, tag, length) do
    updated_warnings =
      add_warning(
        warnings,
        "unexpected tag #{tag} while searching for end of pixel data element with undefined length"
      )

    length = min(length, byte_stream.byte_array.length - byte_stream.position)

    fragment = %{
      offset: byte_stream.position - base_offset - 8,
      position: byte_stream.position,
      length: length
    }

    updated_element = update_in(element.fragments, &(&1 ++ [fragment]))
    {:ok, updated_byte_stream} = ByteStream.seek(byte_stream, length)

    final_element = %{
      updated_element
      | length: updated_byte_stream.position - element.data_offset
    }

    {final_element, updated_byte_stream, updated_warnings}
  end

  # Helper function to add warnings if warnings list is provided
  defp add_warning(nil, _warning), do: nil
  defp add_warning(warnings, warning) when is_list(warnings), do: warnings ++ [warning]
end
