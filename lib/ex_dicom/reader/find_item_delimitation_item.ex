defmodule ExDicom.Reader.FindItemDelimitationItem do
  @moduledoc """
  Internal helper functions for parsing DICOM elements
  """

  alias ExDicom.ByteStream

  @doc """
  Reads from the byte stream until it finds the magic numbers for the item delimitation item
  and then sets the length of the element.

  ## Parameters
    * byte_stream: ByteStream struct
    * element: Map containing element data with :tag and :data_offset fields

  ## Returns
    * `{:ok, element, new_stream}` with updated element length and stream position
    * `{:error, reason}` if byte_stream is nil or if reading fails
  """
  @spec find_item_delimitation_item_and_set_element_length(ByteStream.t() | nil, map()) ::
          {:ok, map(), ByteStream.t()} | {:error, String.t()}
  def find_item_delimitation_item_and_set_element_length(nil, _element) do
    {:error, "readDicomElementImplicit: missing required parameter 'byte_stream'"}
  end

  def find_item_delimitation_item_and_set_element_length(%ByteStream{} = stream, element) do
    # Constants
    # group, element, length
    item_delimitation_item_length = 8
    max_position = ByteStream.get_size(stream) - item_delimitation_item_length

    # Start searching for delimitation item
    search_for_delimitation(stream, element, max_position)
  end

  # Private helper function to recursively search for the delimitation item
  defp search_for_delimitation(%ByteStream{position: pos} = stream, element, max_position)
       when pos <= max_position do
    case ByteStream.read_uint16(stream) do
      {:ok, 0xFFFE, stream_after_group} ->
        # Found potential delimitation group, check element number
        case ByteStream.read_uint16(stream_after_group) do
          {:ok, 0xE00D, stream_after_element} ->
            # Found delimitation element, read length
            case ByteStream.read_uint32(stream_after_element) do
              {:ok, delimiter_length, final_stream} ->
                # Check if length is non-zero and add warning if needed
                final_stream =
                  if delimiter_length != 0 do
                    warning =
                      "encountered non zero length following item delimiter at position #{final_stream.position - 4} " <>
                        "while reading element of undefined length with tag #{element.tag}"

                    %{final_stream | warnings: [warning | final_stream.warnings]}
                  else
                    final_stream
                  end

                # Calculate element length and return
                updated_element =
                  Map.put(element, :length, final_stream.position - element.data_offset)

                {:ok, updated_element, final_stream}

              {:error, reason} ->
                {:error, reason}
            end

          {:ok, _other_element, stream_after_element} ->
            # Not the delimitation element, continue searching
            search_for_delimitation(stream_after_element, element, max_position)

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, _other_group, stream_after_group} ->
        # Not the delimitation group, continue searching
        search_for_delimitation(stream_after_group, element, max_position)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # When position exceeds max_position, set length to end of buffer
  defp search_for_delimitation(%ByteStream{} = stream, element, _max_position) do
    element_length = ByteStream.get_size(stream) - element.data_offset
    updated_element = Map.put(element, :length, element_length)

    # Seek to end of buffer
    case ByteStream.seek(stream, ByteStream.get_size(stream) - stream.position) do
      {:ok, final_stream} -> {:ok, updated_element, final_stream}
      {:error, reason} -> {:error, reason}
    end
  end
end
