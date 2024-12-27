defmodule ExDicom.Reader.ReadEncapsulatedPixelData do
  @moduledoc """
  Functionality for extracting encapsulated pixel data from DICOM fragments.
  """

  alias ExDicom.{Alloc, ByteStream, SharedCopy}
  alias ExDicom.Reader.ReadSequenceItem

  @pixel_data_tag "x7fe00010"
  @basic_offset_table_tag "xfffee000"
  @fragment_header_size 8

  @doc """
  Returns the encapsulated pixel data from the specified fragments.

  ## Parameters
    * dataset - The dataset containing the encapsulated pixel data
    * pixel_data_element - The pixel data element (x7fe00010) to extract from
    * start_fragment_index - Zero based index of the first fragment
    * opts - Optional parameters
      * :num_fragments - Number of fragments to extract (default: 1)
      * :fragments - Optional array of fragment descriptors (default: pixel_data_element.fragments)

  ## Returns
    * `{:ok, binary}` - The extracted pixel data
    * `{:error, reason}` - If extraction fails
  """
  def read_from_fragments(dataset, pixel_data_element, start_fragment_index, opts \\ []) do
    num_fragments = Keyword.get(opts, :num_fragments, 1)
    fragments = Keyword.get(opts, :fragments, pixel_data_element.fragments)

    with :ok <- validate_params(dataset, pixel_data_element, start_fragment_index, num_fragments),
         {:ok, byte_stream} <-
           ByteStream.new(
             dataset.byte_array_parser,
             dataset.byte_array,
             pixel_data_element.data_offset
           ),
         {:ok, basic_offset_table, stream_after_item_tag} <-
           ReadSequenceItem.read_sequence_item(byte_stream) do
      # Validate basic offset table
      if basic_offset_table.tag != @basic_offset_table_tag do
        {:error, "read_from_fragments: missing basic offset table xfffee000"}
      else
        {:ok, seeked_stream} =
          ByteStream.seek(stream_after_item_tag, basic_offset_table.length)

        fragment_zero_position = seeked_stream.position

        if num_fragments == 1 do
          # Return single fragment
          fragment = Enum.at(fragments, start_fragment_index)
          offset = fragment_zero_position + fragment.offset + @fragment_header_size
          SharedCopy.copy(seeked_stream.byte_array, offset, fragment.length)
        else
          # Combine multiple fragments
          buffer_size = calculate_buffer_size(fragments, start_fragment_index, num_fragments)

          with {:ok, pixel_data} <- Alloc.zeros(buffer_size) do
            combine_fragments(
              byte_stream.byte_array,
              fragments,
              start_fragment_index,
              num_fragments,
              fragment_zero_position,
              pixel_data
            )
          end
        end
      end
    end
  end

  defp validate_params(dataset, pixel_data_element, start_fragment_index, num_fragments) do
    cond do
      is_nil(dataset) ->
        {:error, "validate_params: missing required parameter 'dataSet'"}

      is_nil(pixel_data_element) ->
        {:error, "validate_params: missing required parameter 'pixelDataElement'"}

      pixel_data_element.tag != @pixel_data_tag ->
        {:error, "validate_params: non pixel data tag"}

      !pixel_data_element.encapsulated_pixel_data ->
        {:error, "validate_params: not encapsulated pixel data"}

      start_fragment_index < 0 ->
        {:error, "validate_params: startFragmentIndex must be >= 0"}

      num_fragments < 1 ->
        {:error, "validate_params: numFragments must be > 0"}

      true ->
        :ok
    end
  end

  defp calculate_buffer_size(fragments, start_fragment, num_fragments) do
    fragments
    |> Enum.slice(start_fragment, num_fragments)
    |> Enum.reduce(0, fn fragment, acc -> acc + fragment.length end)
  end

  defp combine_fragments(byte_array, fragments, start_idx, num_fragments, zero_pos, pixel_data) do
    fragment_range = start_idx..(start_idx + num_fragments - 1)

    result =
      Enum.reduce_while(fragment_range, {pixel_data, 0}, fn i, {data, data_idx} ->
        fragment = Enum.at(fragments, i)
        fragment_offset = zero_pos + fragment.offset + @fragment_header_size
        fragment_data = binary_part(byte_array, fragment_offset, fragment.length)

        new_data =
          binary_part(data, 0, data_idx) <>
            fragment_data <>
            binary_part(
              data,
              data_idx + byte_size(fragment_data),
              byte_size(data) - data_idx - byte_size(fragment_data)
            )

        {:cont, {new_data, data_idx + fragment.length}}
      end)

    case result do
      {final_data, _} -> {:ok, final_data}
      error -> error
    end
  end
end
