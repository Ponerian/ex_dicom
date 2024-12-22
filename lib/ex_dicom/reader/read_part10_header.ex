defmodule ExDicom.Reader.ReadPart10Header do
  @moduledoc """
  Parses a DICOM P10 byte array and returns a meta-header DataSet.
  """

  alias ExDicom.Parser.LittleEndianByteArrayParser
  alias ExDicom.Reader.ReadDicomElement
  alias ExDicom.{ByteStream, DataSet}

  @dicm_prefix "DICM"
  @default_prefix_offset 128

  @doc """
  Reads the Part 10 header from the given `byte_array`.

  Options can include:
  - `:transfer_syntax_uid`

  Returns `{:ok, meta_header_map_or_struct}` or `{:error, reason}`.

  The `meta_header_map_or_struct` might contain fields:
  - `:elements` => a map of parsed elements
  - `:warnings` => a list of warnings
  - `:position` => the position in the byte stream
  """
  @spec read_part10_header(binary(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def read_part10_header(byte_array, opts \\ [])

  def read_part10_header(nil, _opts) do
    {:error, "readPart10Header: missing required parameter 'byteArray'."}
  end

  def read_part10_header(byte_array, opts) when is_binary(byte_array) do
    transfer_syntax_uid = Keyword.get(opts, :transfer_syntax_uid, nil)

    little_endian_parser = LittleEndianByteArrayParser

    case ByteStream.new(little_endian_parser, byte_array) do
      {:ok, stream} ->
        read_header_result = read_the_header(stream, transfer_syntax_uid)

        case read_header_result do
          {:ok, meta_header_map} ->
            {:ok, meta_header_map}

          {:error, reason, partial_meta_header} ->
            {:error, "#{reason}. Partial header: #{inspect(partial_meta_header)}"}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_the_header(stream, transfer_syntax_uid) do
    case read_prefix(stream, transfer_syntax_uid) do
      {:ok, is_part10, stream_after_prefix, warnings} ->
        if is_part10 do
          # Part 10 file - parse the full meta-header
          do_parse_meta_header(stream_after_prefix, warnings)
        else
          # Not a Part 10 file - return minimal meta-header
          {:ok,
           %DataSet{
             byte_array_parser: stream.byte_array_parser,
             byte_array: stream.byte_array,
             elements: %{
               "x00020010" => %{
                 tag: "x00020010",
                 vr: "UI",
                 Value: transfer_syntax_uid
               }
             },
             warnings: warnings,
             position: 0
           }}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_prefix(stream, transfer_syntax_uid) do
    stream_size = ByteStream.get_size(stream)
    warnings = []

    # First check if the stream is too small to even contain a DICM prefix
    cond do
      # Case 1: Stream too small for DICM prefix
      stream_size <= @default_prefix_offset + 4 ->
        if transfer_syntax_uid do
          {:ok, false, stream, warnings}
        else
          raise "Not a valid DICOM P10 file - file is too small to contain DICM prefix"
        end

      # Case 2: Stream is large enough to potentially have DICM prefix
      true ->
        with {:ok, stream_after_seek} <- ByteStream.seek(stream, @default_prefix_offset),
             {:ok, prefix, stream_after_read} <-
               ByteStream.read_fixed_string(stream_after_seek, 4) do
          cond do
            prefix == @dicm_prefix ->
              {:ok, true, stream_after_read, warnings}

            is_nil(transfer_syntax_uid) ->
              raise "DICM prefix not found at location 132 - not a valid DICOM P10 file."

            true ->
              case ByteStream.seek(stream, 0) do
                {:ok, reverted_stream} -> {:ok, false, reverted_stream, warnings}
                {:error, reason} -> {:error, reason}
              end
          end
        end
    end
  end

  # Actually parse meta-header elements in explicit VR Little Endian until
  # we see a tag > 'x0002ffff'
  defp do_parse_meta_header(stream, incoming_warnings) do
    parse_meta_header_loop(stream, %{}, incoming_warnings)
  end

  defp parse_meta_header_loop(stream, elements_map, warnings) do
    if stream.position < ByteStream.get_size(stream) do
      position_before_element = stream.position

      # read one element
      case ReadDicomElement.read_dicom_element_explicit(stream, warnings) do
        {:ok, element, stream_after_element, updated_warnings} ->
          # If element.tag > 'x0002ffff', we stop
          if element.tag > "x0002ffff" do
            # revert the stream to position_before_element
            case ByteStream.seek(
                   stream_after_element,
                   position_before_element - stream_after_element.position
                 ) do
              {:ok, reverted_stream} ->
                # return the dataset
                build_meta_header_data_set(elements_map, reverted_stream, updated_warnings)

              {:error, reason} ->
                {:error, reason,
                 build_meta_header_data_set(elements_map, stream_after_element, updated_warnings)}
            end
          else
            updated_element = Map.put(element, :parser, ExDicom.LittleEndianByteArrayParser)
            new_elements_map = Map.put(elements_map, element.tag, updated_element)
            parse_meta_header_loop(stream_after_element, new_elements_map, updated_warnings)
          end

        {:error, reason} ->
          # Return partial
          partial_data_set = build_meta_header_data_set(elements_map, stream, warnings)
          {:error, reason, partial_data_set}
      end
    else
      # we're at/over the end => return what we have
      build_meta_header_data_set(elements_map, stream, warnings)
    end
  end

  # Helper to build the final meta-header data set structure
  defp build_meta_header_data_set(elements_map, stream, warnings) do
    meta_data_set = %DataSet{
      byte_array_parser: stream.byte_array_parser,
      byte_array: stream.byte_array,
      elements: elements_map,
      warnings: warnings,
      position: stream.position
    }

    {:ok, meta_data_set}
  end
end
