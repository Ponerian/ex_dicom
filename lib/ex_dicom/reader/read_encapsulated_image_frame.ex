defmodule ExDicom.Reader.ReadEncapsulatedImageFrame do
  @moduledoc """
  Functionality for extracting encapsulated image frames from DICOM data.
  """

  alias ExDicom.Reader.ReadEncapsulatedPixelData

  @pixel_data_tag "x7fe00010"

  @doc """
  Returns the pixel data for the specified frame in an encapsulated pixel data element
  that has a non-empty basic offset table.

  ## Parameters
    * dataset - The dataset containing the encapsulated pixel data
    * pixel_data_element - The pixel data element (x7fe00010) to extract from
    * frame_index - Zero based frame index
    * opts - Optional parameters
      * :basic_offset_table - Optional array of starting offsets for frames
      * :fragments - Optional array of fragment descriptors

  ## Returns
    * {:ok, binary} - The extracted frame data
    * {:error, reason} - If extraction fails
  """
  def read_frame(dataset, pixel_data_element, frame_index, opts \\ []) do
    basic_offset_table =
      Keyword.get(opts, :basic_offset_table, pixel_data_element.basic_offset_table)

    fragments = Keyword.get(opts, :fragments, pixel_data_element.fragments)

    with :ok <- validate_params(dataset, pixel_data_element, frame_index, basic_offset_table),
         offset = Enum.at(basic_offset_table, frame_index),
         {:ok, start_fragment_index} <- find_fragment_index_with_offset(fragments, offset),
         {:ok, num_fragments} <-
           calculate_num_fragments_for_frame(
             frame_index,
             basic_offset_table,
             fragments,
             start_fragment_index
           ) do
      ReadEncapsulatedPixelData.read_from_fragments(
        dataset,
        pixel_data_element,
        start_fragment_index,
        num_fragments: num_fragments,
        fragments: fragments
      )
    end
  end

  defp validate_params(dataset, pixel_data_element, frame_index, basic_offset_table) do
    cond do
      is_nil(dataset) ->
        {:error, "dicomParser.readEncapsulatedImageFrame: missing required parameter 'dataSet'"}

      is_nil(pixel_data_element) ->
        {:error,
         "dicomParser.readEncapsulatedImageFrame: missing required parameter 'pixelDataElement'"}

      pixel_data_element.tag != @pixel_data_tag ->
        {:error, "dicomParser.readEncapsulatedImageFrame: non pixel data tag"}

      !pixel_data_element.encapsulated_pixel_data ->
        {:error, "dicomParser.readEncapsulatedImageFrame: not encapsulated pixel data"}

      !pixel_data_element.had_undefined_length ->
        {:error,
         "dicomParser.readEncapsulatedImageFrame: pixel data element does not have undefined length"}

      Enum.empty?(basic_offset_table) ->
        {:error, "dicomParser.readEncapsulatedImageFrame: basicOffsetTable has zero entries"}

      frame_index < 0 ->
        {:error, "dicomParser.readEncapsulatedImageFrame: frameIndex must be >= 0"}

      frame_index >= length(basic_offset_table) ->
        {:error,
         "dicomParser.readEncapsulatedImageFrame: frameIndex must be < basicOffsetTable.length"}

      true ->
        :ok
    end
  end

  defp find_fragment_index_with_offset(fragments, offset) do
    case Enum.find_index(fragments, &(&1.offset == offset)) do
      nil ->
        {:error,
         "dicomParser.readEncapsulatedImageFrame: unable to find fragment matching basic offset table entry"}

      index ->
        {:ok, index}
    end
  end

  defp calculate_num_fragments_for_frame(
         frame_index,
         basic_offset_table,
         fragments,
         start_fragment_index
       ) do
    # Special case for last frame
    if frame_index == length(basic_offset_table) - 1 do
      {:ok, length(fragments) - start_fragment_index}
    else
      next_frame_offset = Enum.at(basic_offset_table, frame_index + 1)

      case Enum.find_index(fragments, &(&1.offset == next_frame_offset)) do
        nil ->
          {:error,
           "dicomParser.calculateNumberOfFragmentsForFrame: could not find fragment with offset matching basic offset table"}

        index ->
          {:ok, index - start_fragment_index}
      end
    end
  end
end
