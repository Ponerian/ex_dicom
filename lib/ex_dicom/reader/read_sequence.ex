defmodule ExDicom.Reader.ReadSequence do
  @moduledoc """
  Provides functions to read DICOM sequence items in both explicit and implicit VR.
  """

  alias ExDicom.Reader.ReadSequenceItem
  alias ExDicom.Parser.DicomDataSet
  alias ExDicom.ByteStream
  alias ExDicom.DataSet
  alias ExDicom.Reader.ReadTag
  alias ExDicom.Reader.ReadDicomElement

  @undefined_length 0xFFFFFFFF
  @item_delimitation_tag "xFFFEE00D"
  @sequence_delimitation_tag "xFFFEE0DD"

  # ----------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------

  @doc """
  Reads sequence items for an element in an **explicit** VR byte stream.

  Returns:
  - `{:ok, updated_element, updated_stream, updated_warnings}` on success
  - `{:error, reason}` on failure
  """
  def read_sequence_items_explicit(byte_stream, element, warnings \\ [])

  def read_sequence_items_explicit(nil, _element, _warnings) do
    {:error, "read_sequence_items_explicit: missing 'byte_stream' parameter"}
  end

  def read_sequence_items_explicit(_byte_stream, nil, _warnings) do
    {:error, "read_sequence_items_explicit: missing 'element' parameter"}
  end

  def read_sequence_items_explicit(byte_stream, element, warnings) do
    # Initialize items to an empty list
    element = Map.put(element, :items, [])

    cond do
      element.length == @undefined_length ->
        read_sq_element_undefined_length_explicit(byte_stream, element, warnings)

      true ->
        read_sq_element_known_length_explicit(byte_stream, element, warnings)
    end
  end

  @doc """
  Reads sequence items for an element in an **implicit** VR byte stream.

  Returns:
  - `{:ok, updated_element, updated_stream, updated_warnings}` on success
  - `{:error, reason}` on failure
  """
  def read_sequence_items_implicit(byte_stream, element, vr_callback \\ nil)

  def read_sequence_items_implicit(nil, _element, _vr_callback) do
    {:error, "read_sequence_items_implicit: missing 'byte_stream' parameter"}
  end

  def read_sequence_items_implicit(_byte_stream, nil, _vr_callback) do
    {:error, "read_sequence_items_implicit: missing 'element' parameter"}
  end

  def read_sequence_items_implicit(byte_stream, element, vr_callback) do
    # Initialize items to an empty list
    element = Map.put(element, :items, [])

    cond do
      element.length == @undefined_length ->
        read_sq_element_undefined_length_implicit(byte_stream, element, vr_callback)

      true ->
        read_sq_element_known_length_implicit(byte_stream, element, vr_callback)
    end
  end

  # ----------------------------------------------------------------------
  # (EXPLICIT)
  # ----------------------------------------------------------------------

  defp read_sq_element_undefined_length_explicit(byte_stream, element, warnings) do
    # We'll loop until we encounter the 'sequence delimitation item' tag or EOF
    do_read_sq_undef_length_explicit(byte_stream, element, warnings)
  end

  defp do_read_sq_undef_length_explicit(byte_stream, element, warnings) do
    # Check if we have enough bytes to read next tag
    if byte_stream.position + 4 <= ByteStream.get_size(byte_stream) do
      # read next tag
      case ReadTag.read_tag(byte_stream) do
        {:ok, next_tag, stream_after_tag} ->
          # We revert the tag read by seeking -4
          case ByteStream.seek(stream_after_tag, -4) do
            {:ok, rewind_stream} ->
              if next_tag == @sequence_delimitation_tag do
                # We found the sequence delimitation. Update element.length & skip 8
                new_length = rewind_stream.position - element.data_offset

                case ByteStream.seek(rewind_stream, 8) do
                  {:ok, stream_after_seek} ->
                    updated_element =
                      element
                      |> Map.put(:length, new_length)

                    {:ok, updated_element, stream_after_seek, warnings}

                  {:error, reason} ->
                    {:error, reason}
                end
              else
                # Not the delimitation; read next item
                case read_sequence_item_explicit(rewind_stream, warnings) do
                  {:ok, item, stream_after_item, new_warnings} ->
                    updated_items = element.items ++ [item]
                    updated_element = %{element | items: updated_items}
                    # Recurse to continue reading
                    do_read_sq_undef_length_explicit(
                      stream_after_item,
                      updated_element,
                      new_warnings
                    )

                  {:error, reason} ->
                    {:error, reason}
                end
              end

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      # EOF encountered before finding sequence delimitation
      new_warnings =
        warnings ++
          [
            "EOF encountered before finding sequence delimitation tag in undefined-length explicit sequence"
          ]

      new_length = byte_stream.position - element.data_offset
      updated_element = %{element | length: new_length}

      {:ok, updated_element, byte_stream, new_warnings}
    end
  end

  defp read_sq_element_known_length_explicit(byte_stream, element, warnings) do
    max_position = element.data_offset + element.length
    do_read_sq_known_length_explicit(byte_stream, element, warnings, max_position)
  end

  defp do_read_sq_known_length_explicit(byte_stream, element, warnings, max_position) do
    if byte_stream.position < max_position do
      # Still have room to read next item
      case read_sequence_item_explicit(byte_stream, warnings) do
        {:ok, item, stream_after_item, new_warnings} ->
          updated_items = element.items ++ [item]
          updated_element = %{element | items: updated_items}

          do_read_sq_known_length_explicit(
            stream_after_item,
            updated_element,
            new_warnings,
            max_position
          )

        {:error, reason} ->
          {:error, reason}
      end
    else
      # We have read up to or past max_position
      {:ok, element, byte_stream, warnings}
    end
  end

  defp read_sequence_item_explicit(byte_stream, warnings) do
    with {:ok, item, stream_after_item_tag} <- ReadSequenceItem.read_sequence_item(byte_stream),
         item_length = item.length,
         data_offset = item.data_offset do
      if item_length == @undefined_length do
        # hadUndefinedLength
        item = Map.put(item, :hadUndefinedLength, true)
        # read Dicoms until item delimiter
        case read_dicom_data_set_explicit_undefined_length(stream_after_item_tag, warnings) do
          {:ok, data_set, stream_after_dataset, new_warnings} ->
            # item length is now updated
            final_length = stream_after_dataset.position - data_offset

            updated_item =
              item
              |> Map.put(:dataSet, data_set)
              |> Map.put(:length, final_length)

            {:ok, updated_item, stream_after_dataset, new_warnings}

          {:error, reason} ->
            {:error, reason}
        end
      else
        empty_data_set = DataSet.new(byte_stream.byte_array_parser, byte_stream.byte_array, %{})
        parse_end = stream_after_item_tag.position + item_length

        case DicomDataSet.parse_explicit(
               empty_data_set,
               stream_after_item_tag,
               parse_end
             ) do
          {:ok, updated_data_set} ->
            updated_item =
              item
              |> Map.put(:dataSet, updated_data_set)

            {:ok, updated_item, stream_after_item_tag, stream_after_item_tag.warnings}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defp read_dicom_data_set_explicit_undefined_length(byte_stream, warnings) do
    do_read_dicom_data_set_explicit_undefined_length(byte_stream, %{}, warnings)
  end

  defp do_read_dicom_data_set_explicit_undefined_length(byte_stream, elements_map, warnings) do
    remaining_bytes = ByteStream.get_size(byte_stream) - byte_stream.position

    cond do
      # If we have exactly 0 or 1 byte remaining, we've reached the end
      remaining_bytes <= 1 ->
        # Create final dataset
        data_set =
          DataSet.new(
            byte_stream.byte_array_parser,
            byte_stream.byte_array,
            elements_map
          )

        {:ok, data_set, byte_stream, warnings ++ ["Reached end of file"]}

      # Normal case - continue reading
      byte_stream.position < ByteStream.get_size(byte_stream) ->
        # read next element
        case ReadDicomElement.read_dicom_element_explicit(byte_stream, warnings) do
          {:ok, element, updated_stream, new_warnings} ->
            updated_elements = Map.put(elements_map, element.tag, element)

            if element.tag == @item_delimitation_tag do
              # Reached item delimiter
              data_set =
                DataSet.new(
                  updated_stream.byte_array_parser,
                  updated_stream.byte_array,
                  updated_elements
                )

              {:ok, data_set, updated_stream, new_warnings}
            else
              # Keep reading
              do_read_dicom_data_set_explicit_undefined_length(
                updated_stream,
                updated_elements,
                new_warnings
              )
            end

          {:error, reason} ->
            {:error, reason}
        end

      true ->
        {:error, "Unexpected end of DICOM data"}
    end
  end

  # ----------------------------------------------------------------------
  # (IMPLICIT)
  # ----------------------------------------------------------------------

  defp read_sq_element_undefined_length_implicit(byte_stream, element, vr_callback) do
    do_read_sq_undef_length_implicit(byte_stream, element, vr_callback)
  end

  defp do_read_sq_undef_length_implicit(byte_stream, element, vr_callback) do
    if byte_stream.position + 4 <= ByteStream.get_size(byte_stream) do
      case ReadTag.read_tag(byte_stream) do
        {:ok, next_tag, stream_after_tag} ->
          case ByteStream.seek(stream_after_tag, -4) do
            {:ok, rewind_stream} ->
              if next_tag == @sequence_delimitation_tag do
                # We found the sequence delimitation
                new_length = rewind_stream.position - element.data_offset

                case ByteStream.seek(rewind_stream, 8) do
                  {:ok, stream_after_seek} ->
                    updated_element = Map.put(element, :length, new_length)
                    {:ok, updated_element, stream_after_seek, rewind_stream.warnings}

                  {:error, reason} ->
                    {:error, reason}
                end
              else
                # Read next item
                case read_sequence_item_implicit(rewind_stream, vr_callback) do
                  {:ok, item, updated_stream, _maybe_new_warnings} ->
                    new_items = element.items ++ [item]
                    updated_element = %{element | items: new_items}
                    do_read_sq_undef_length_implicit(updated_stream, updated_element, vr_callback)

                  {:error, reason} ->
                    {:error, reason}
                end
              end

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      # EOF encountered
      new_warnings =
        ByteStream.add_warning(
          byte_stream,
          "EOF before finding sequence delimiter in undefined-length implicit sequence"
        )

      new_length = ByteStream.get_size(byte_stream) - element.data_offset
      updated_element = %{element | length: new_length}
      {:ok, updated_element, byte_stream, new_warnings.warnings}
    end
  end

  defp read_sq_element_known_length_implicit(byte_stream, element, vr_callback) do
    max_position = element.data_offset + element.length
    do_read_sq_known_length_implicit(byte_stream, element, vr_callback, max_position)
  end

  defp do_read_sq_known_length_implicit(byte_stream, element, vr_callback, max_position) do
    if byte_stream.position < max_position do
      case read_sequence_item_implicit(byte_stream, vr_callback) do
        {:ok, item, updated_stream, _} ->
          new_items = element.items ++ [item]
          updated_element = %{element | items: new_items}

          do_read_sq_known_length_implicit(
            updated_stream,
            updated_element,
            vr_callback,
            max_position
          )

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, element, byte_stream, byte_stream.warnings}
    end
  end

  defp read_sequence_item_implicit(byte_stream, vr_callback) do
    with {:ok, item, stream_after_item_tag} <- ReadSequenceItem.read_sequence_item(byte_stream),
         item_length = item.length,
         data_offset = item.data_offset do
      if item_length == @undefined_length do
        item = Map.put(item, :hadUndefinedLength, true)

        case read_dicom_data_set_implicit_undefined_length(stream_after_item_tag, vr_callback) do
          {:ok, data_set, stream_after_dataset} ->
            final_length = stream_after_dataset.position - data_offset

            updated_item =
              item
              |> Map.put(:dataSet, data_set)
              |> Map.put(:length, final_length)

            {:ok, updated_item, stream_after_dataset, stream_after_dataset.warnings}

          {:error, reason} ->
            {:error, reason}
        end
      else
        empty_data_set = DataSet.new(byte_stream.byte_array_parser, byte_stream.byte_array, %{})
        parse_end = stream_after_item_tag.position + item_length

        case DicomDataSet.parse_implicit(
               empty_data_set,
               stream_after_item_tag,
               parse_end,
               vr_callback
             ) do
          {:ok, updated_data_set} ->
            updated_item = Map.put(item, :dataSet, updated_data_set)
            {:ok, updated_item, stream_after_item_tag, stream_after_item_tag.warnings}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defp read_dicom_data_set_implicit_undefined_length(byte_stream, vr_callback) do
    do_read_dicom_data_set_implicit_undefined_length(byte_stream, %{}, vr_callback)
  end

  defp do_read_dicom_data_set_implicit_undefined_length(byte_stream, elements_map, vr_callback) do
    if byte_stream.position < ByteStream.get_size(byte_stream) do
      case ReadDicomElement.read_dicom_element_implicit(byte_stream, vr_callback) do
        {:ok, element, updated_stream, _warnings} ->
          new_map = Map.put(elements_map, element.tag, element)

          if element.tag == @item_delimitation_tag do
            data_set =
              DataSet.new(updated_stream.byte_array_parser, updated_stream.byte_array, new_map)

            {:ok, data_set, updated_stream}
          else
            do_read_dicom_data_set_implicit_undefined_length(updated_stream, new_map, vr_callback)
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      # EOF before item delimiter
      updated_stream =
        ByteStream.add_warning(
          byte_stream,
          "EOF before finding item delimiter in implicit undefined-length sequence item"
        )

      data_set =
        DataSet.new(updated_stream.byte_array_parser, updated_stream.byte_array, elements_map)

      {:ok, data_set, updated_stream}
    end
  end
end
