defmodule ExDicom.Reader.ReadDicomElement do
  @moduledoc """
  Provides functions to read a single DICOM element in either Implicit or Explicit VR format.
  """

  alias ExDicom.Util.Misc
  alias ExDicom.ByteStream

  alias ExDicom.Reader.{
    ReadTag,
    ReadSequence,
    FindItemDelimitationItem,
    FindEndOfEncapsulatedElement
  }

  @undefined_length 0xFFFFFFFF

  # -----------------------------------------------------------------------
  #  IMPLICIT
  # -----------------------------------------------------------------------

  @doc """
  Reads one DICOM element from the byte stream using implicit VR rules.

  ## Parameters
  - `byte_stream`: the ByteStream
  - `until_tag`: optional tag; if we encounter it, we immediately return the element
  - `vr_callback`: (optional) a function that returns a VR given a tag (for private dictionary lookups, etc.)

  ## Return Value
  Typically returns `{:ok, element, updated_stream, warnings}` or `{:error, reason}`.
  """
  def read_dicom_element_implicit(byte_stream, until_tag \\ nil, vr_callback \\ nil)

  def read_dicom_element_implicit(nil, _until_tag, _vr_callback) do
    {:error, "read_dicom_element_implicit: missing required parameter 'byteStream'"}
  end

  def read_dicom_element_implicit(byte_stream, until_tag, vr_callback) do
    # 1) Read the tag
    with {:ok, tag, stream1} <- ReadTag.read_tag(byte_stream),
         vr <- if(vr_callback, do: vr_callback.(tag), else: nil),
         {:ok, length, stream2} <- ByteStream.read_uint32(stream1) do
      element = %{
        tag: tag,
        vr: vr,
        length: length,
        data_offset: stream2.position
      }

      element =
        if length == @undefined_length do
          Map.put(element, :hadUndefinedLength, true)
        else
          element
        end

      # 4) If we hit the `until_tag`, just return immediately
      if tag == until_tag do
        {:ok, element, stream2, stream2.warnings}
      else
        # 5) Check if it’s a sequence (always parse undefined-length sequences)
        {is_seq, stream_after_check} = is_sequence?(element, stream2)

        case is_seq and (not Misc.private_tag?(tag) or element[:hadUndefinedLength]) do
          true ->
            # read sequence items
            case ReadSequence.read_sequence_items_implicit(
                   stream_after_check,
                   element,
                   vr_callback
                 ) do
              {:ok, updated_element, stream_after_seq, warnings} ->
                final_element =
                  if Misc.private_tag?(tag) do
                    Map.delete(updated_element, :items)
                  else
                    updated_element
                  end

                {:ok, final_element, stream_after_seq, warnings}

              {:error, reason} ->
                {:error, reason}
            end

          false ->
            cond do
              # 6) If not a sequence but has undefined length
              element[:hadUndefinedLength] ->
                # find item delimitation item
                case FindItemDelimitationItem.find_item_delimitation_item_and_set_element_length(
                       stream2,
                       element
                     ) do
                  {:ok, final_element, updated_stream} ->
                    # Get warnings from the updated stream
                    {:ok, final_element, updated_stream, updated_stream.warnings}

                  {:error, reason} ->
                    {:error, reason}
                end

              # 7) Otherwise, known length => seek over the data
              true ->
                case ByteStream.seek(stream2, element.length) do
                  {:ok, stream_after_seek} ->
                    {:ok, element, stream_after_seek, stream_after_seek.warnings}

                  {:error, reason} ->
                    {:error, reason}
                end
            end
        end
      end
    end
  end

  # -----------------------------------------------------------------------
  #  EXPLICIT
  # -----------------------------------------------------------------------

  @doc """
  Reads one DICOM element from the byte stream using explicit VR rules.

  ## Parameters
  - `byte_stream`: the ByteStream
  - `warnings`: a list of warnings (if you track them separately from the stream)
  - `until_tag`: optional tag that, if matched, stops reading

  ## Return Value
  `{:ok, element, updated_stream, updated_warnings}` or `{:error, reason}`
  """
  def read_dicom_element_explicit(byte_stream, warnings \\ [], until_tag \\ nil)

  def read_dicom_element_explicit(nil, _warnings, _until_tag) do
    {:error, "read_dicom_element_explicit: missing 'byteStream' parameter"}
  end

  def read_dicom_element_explicit(byte_stream, warnings, until_tag) do
    # 1) Read the tag
    with {:ok, tag, stream1} <- ReadTag.read_tag(byte_stream),
         # 2) Read VR (2 bytes)
         {:ok, vr_str, stream2} <- ByteStream.read_fixed_string(stream1, 2) do
      # 3) Determine length size from VR
      data_length_size = get_data_length_size_in_bytes_for_vr(vr_str)

      # 4) Read length accordingly
      case read_length(stream2, data_length_size) do
        {:ok, {length, stream3}, length_warnings} ->
          element = %{
            tag: tag,
            vr: vr_str,
            length: length,
            data_offset: stream3.position
          }

          element =
            if length == @undefined_length do
              Map.put(element, :hadUndefinedLength, true)
            else
              element
            end

          updated_warnings = warnings ++ length_warnings

          # If we hit the until_tag
          if tag == until_tag do
            {:ok, element, stream3, updated_warnings}
          else
            cond do
              # 5) If VR=SQ => read sequence items (explicit)
              vr_str == "SQ" ->
                case ReadSequence.read_sequence_items_explicit(stream3, element, updated_warnings) do
                  {:ok, updated_element, stream_after_seq, seq_warnings} ->
                    {:ok, updated_element, stream_after_seq, seq_warnings}

                  {:error, reason} ->
                    {:error, reason}
                end

              # 6) If length is undefined
              length == @undefined_length ->
                cond do
                  tag == "x7fe00010" ->
                    # Pixel data
                    case FindEndOfEncapsulatedElement.find(stream3, element, updated_warnings) do
                      {:ok, updated_element, updated_stream, new_warnings} ->
                        {:ok, updated_element, updated_stream, new_warnings}

                      {:error, reason} ->
                        {:error, reason}
                    end

                  vr_str == "UN" ->
                    # read sequence items implicit
                    case ReadSequence.read_sequence_items_implicit(stream3, element) do
                      {:ok, updated_element, updated_stream, new_warnings} ->
                        {:ok, updated_element, updated_stream, updated_warnings ++ new_warnings}

                      {:error, reason} ->
                        {:error, reason}
                    end

                  true ->
                    # find item delimitation item
                    case FindItemDelimitationItem.find_item_delimitation_item_and_set_element_length(
                           stream3,
                           element
                         ) do
                      {:ok, updated_element, updated_stream} ->
                        {:ok, updated_element, updated_stream,
                         updated_warnings ++ updated_stream.warnings}

                      {:error, reason} ->
                        {:error, reason}
                    end
                end

              # 7) Otherwise, known length => seek
              true ->
                case ByteStream.seek(stream3, length) do
                  {:ok, stream_after_seek} ->
                    {:ok, element, stream_after_seek, updated_warnings}

                  {:error, reason} ->
                    {:error, reason}
                end
            end
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp get_data_length_size_in_bytes_for_vr(vr) do
    case vr do
      "OB" -> 4
      "OD" -> 4
      "OL" -> 4
      "OW" -> 4
      "SQ" -> 4
      "OF" -> 4
      "UC" -> 4
      "UR" -> 4
      "UT" -> 4
      "UN" -> 4
      _ -> 2
    end
  end

  # Reads the length field depending on `data_length_size`.
  # If 2 => read a uint16
  # If 4 => skip 2 + read a uint32
  defp read_length(stream, 2) do
    case ByteStream.read_uint16(stream) do
      {:ok, length, updated_stream} ->
        {:ok, {length, updated_stream}, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_length(stream, 4) do
    # skip 2 bytes, then read 32
    with {:ok, stream_skip2} <- ByteStream.seek(stream, 2),
         {:ok, length32, updated_stream} <- ByteStream.read_uint32(stream_skip2) do
      {:ok, {length32, updated_stream}, []}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec is_sequence?(map(), ByteStream.t()) ::
          {boolean(), ByteStream.t()}
  defp is_sequence?(element, stream) do
    cond do
      # If VR is explicitly set to "SQ"
      element[:vr] == "SQ" ->
        {true, stream}

      # If we have enough bytes, peek next tag
      stream.position + 4 <= ByteStream.get_size(stream) ->
        # read next tag, then seek back
        with {:ok, next_tag, read_stream} <- ReadTag.read_tag(stream),
             {:ok, seeked_stream} <- ByteStream.seek(read_stream, -4) do
          {next_tag in ["xFFFEE000", "xFFFEE0DD"], seeked_stream}
        else
          _ ->
            # If we fail to read or seek, we can't confirm it's a sequence
            # Possibly add a warning or return false
            new_stream =
              ByteStream.add_warning(
                stream,
                "Unable to determine if element #{element.tag} is a sequence - failed to read next tag or seek back"
              )

            {false, new_stream}
        end

      true ->
        new_stream =
          ByteStream.add_warning(
            stream,
            "EOF encountered before peeking next tag for VR sequence check"
          )

        {false, new_stream}
    end
  end
end
