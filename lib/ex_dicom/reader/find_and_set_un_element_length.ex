defmodule ExDicom.Reader.FindAndSetUNElementLength do
  @moduledoc """
  Internal helper functions for parsing DICOM elements.
  """

  @doc """
  Reads from the byte stream until it finds the magic number for the Sequence Delimitation
  Item and then sets the length of the element.

  ## Parameters
    * byte_stream - The byte stream to read from. Must implement the following functions:
      * read_uint16/0 - Reads an unsigned 16-bit integer from the stream
      * read_uint32/0 - Reads an unsigned 32-bit integer from the stream
      * warnings/1 - Logs warning messages
      * seek/1 - Moves the stream position by given offset
      Additionally, must have these fields:
      * position - Current position in the stream
      * byte_array - The underlying byte array
    * element - The DICOM element to update. Must have these fields:
      * tag - The element's tag
      * data_offset - Offset to the element's data
      Length will be set on this element.

  ## Returns
    The updated element with its length field set.

  ## Examples
      iex> byte_stream = MockByteStream.new(...)
      iex> element = %{tag: "x00100010", data_offset: 0}
      iex> FindAndSetUNElementLength.find_and_set_un_element_length(byte_stream, element)
      %{tag: "x00100010", data_offset: 0, length: 42}

  ## Errors
      * ArgumentError - If byte_stream is nil or doesn't implement required functions
  """
  @spec find_and_set_un_element_length(any(), map()) :: map() | no_return()
  def find_and_set_un_element_length(nil, _element) do
    raise ArgumentError, "missing required parameter 'byte_stream'"
  end

  def find_and_set_un_element_length(byte_stream, element) do
    # Verify byte_stream implements required functions
    unless implements_required_functions?(byte_stream) do
      raise ArgumentError, "byte_stream must implement required interface"
    end

    # Constants
    item_delimitation_item_length = 8
    max_position = byte_length(byte_stream.byte_array) - item_delimitation_item_length

    # Try to find delimitation item
    case find_delimitation_item(byte_stream, element, max_position) do
      {:found, updated_element} ->
        updated_element

      :not_found ->
        handle_missing_delimitation(byte_stream, element)
    end
  end

  defp implements_required_functions?(byte_stream) do
    # Check if byte_stream implements all required functions
    Enum.all?(
      [
        :read_uint16,
        :read_uint32,
        :warnings,
        :seek,
        :position,
        :byte_array
      ],
      fn function ->
        function_exported?(byte_stream.__struct__, function, 0) ||
          Map.has_key?(byte_stream, function)
      end
    )
  end

  defp find_delimitation_item(byte_stream, element, max_position) do
    find_delimitation_item_loop(byte_stream, element, max_position)
  end

  defp find_delimitation_item_loop(byte_stream, element, max_position) do
    if byte_stream.position <= max_position do
      case byte_stream.read_uint16() do
        0xFFFE ->
          case byte_stream.read_uint16() do
            0xE0DD ->
              # Check delimiter length
              delimiter_length = byte_stream.read_uint32()

              if delimiter_length != 0 do
                byte_stream.warnings.(
                  "encountered non zero length following item delimiter at position #{byte_stream.position - 4} " <>
                    "while reading element of undefined length with tag #{element.tag}"
                )
              end

              # Update element length and return
              updated_element =
                Map.put(element, :length, byte_stream.position - element.data_offset)

              {:found, updated_element}

            _other ->
              # Continue searching
              find_delimitation_item_loop(byte_stream, element, max_position)
          end

        _other ->
          # Continue searching
          find_delimitation_item_loop(byte_stream, element, max_position)
      end
    else
      :not_found
    end
  end

  defp handle_missing_delimitation(byte_stream, element) do
    # No item delimitation item found - set length to end of buffer
    new_length = byte_length(byte_stream.byte_array) - element.data_offset

    # Seek to end of buffer
    seek_amount = byte_length(byte_stream.byte_array) - byte_stream.position
    byte_stream.seek.(seek_amount)

    # Return updated element
    Map.put(element, :length, new_length)
  end

  defp byte_length(byte_array) when is_binary(byte_array), do: byte_size(byte_array)
  defp byte_length(byte_array) when is_list(byte_array), do: length(byte_array)
  defp byte_length(_), do: raise(ArgumentError, "byte_array must be binary or list")
end
