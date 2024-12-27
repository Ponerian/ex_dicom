defmodule ExDicom.Parser do
  @moduledoc """
  Parses a DICOM P10 byte array and returns a DataSet object with the parsed elements.
  """

  alias ExDicom.{ByteArrayParser, ByteStream, DataSet, SharedCopy}
  alias ExDicom.Parser.{BigEndianParser, DicomDataSet, LittleEndianByteArrayParser}
  alias ExDicom.Reader.ReadPart10Header

  # Transfer Syntax UIDs
  @lei "1.2.840.10008.1.2"
  @lee "1.2.840.10008.1.2.1"
  @bei "1.2.840.10008.1.2.2"
  @deflated "1.2.840.10008.1.2.1.99"

  def lei, do: @lei
  def lee, do: @lee
  def bei, do: @bei
  def deflated, do: @deflated

  @doc """
  Parses a DICOM P10 byte array and returns a DataSet object with the parsed elements.
  If the options argument contains the :until_tag property, parsing will stop once
  that tag is encountered.

  ## Parameters
    * byte_array - The binary containing DICOM data
    * opts - Options to control parsing behavior (optional)
      * :until_tag - Stop parsing when this tag is encountered
      * :inflater - Function to handle deflated transfer syntax

  ## Returns
    * `{:ok, dataset}` - Successfully parsed DICOM data
    * `{:error, reason}` - Error occurred during parsing

  ## Examples
      iex> Parser.parse_dicom(<<...>>)
      {:ok, %DataSet{...}}
  """
  @spec parse_dicom(binary(), keyword()) :: {:ok, DataSet.t()} | {:error, String.t()}
  def parse_dicom(byte_array, opts \\ [])

  def parse_dicom(nil, _opts),
    do: {:error, "parse_dicom: missing required parameter 'byteArray'"}

  def parse_dicom(byte_array, opts) when is_binary(byte_array) do
    try do
      {:ok, parse_byte_stream(byte_array, opts)}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_byte_stream(byte_array, opts) do
    with {:ok, meta_header_dataset} <- ReadPart10Header.read_part10_header(byte_array, opts),
         {:ok, dataset} <- read_dataset(meta_header_dataset) do
      merge_datasets(meta_header_dataset, dataset)
    end
  end

  defp read_transfer_syntax(meta_header_dataset) do
    case meta_header_dataset.elements["x00020010"] do
      nil ->
        {:error, "parse_dicom: missing required meta header attribute 0002,0010"}

      element ->
        value =
          Map.get(element, :value) ||
            ByteArrayParser.read_fixed_string(
              meta_header_dataset.byte_array,
              element.data_offset,
              element.length
            )

        {:ok, value}
    end
  end

  defp is_explicit?(transfer_syntax) do
    # implicit little endian is the only non-explicit transfer syntax
    transfer_syntax != @lei
  end

  defp get_dataset_byte_stream(transfer_syntax, position, byte_array, opts) do
    case transfer_syntax do
      @deflated -> handle_deflated_syntax(byte_array, position, opts)
      @bei -> ByteStream.new(BigEndianParser, byte_array, position)
      _ -> ByteStream.new(LittleEndianByteArrayParser, byte_array, position)
    end
  end

  defp handle_deflated_syntax(byte_array, position, opts) do
    cond do
      inflater = opts[:inflater] ->
        # Use provided inflater callback
        full_byte_array = inflater.(byte_array, position)
        {:ok, ByteStream.new(LittleEndianByteArrayParser, full_byte_array, 0)}

      Code.ensure_loaded?(:zlib) ->
        # Use zlib for inflation
        with {:ok, deflated} <-
               SharedCopy.copy(byte_array, position, byte_size(byte_array) - position),
             z = :zlib.open(),
             # -15 for raw deflate
             :ok = :zlib.inflateInit(z, -15),
             inflated = :zlib.inflate(z, deflated) |> IO.iodata_to_binary(),
             :ok = :zlib.inflateEnd(z),
             :ok = :zlib.close(z) do
          full_binary = binary_part(byte_array, 0, position) <> inflated
          {:ok, ByteStream.new(LittleEndianByteArrayParser, full_binary, 0)}
        end

      true ->
        {:error,
         "handle_deflated_syntax: no inflater available to handle deflate transfer syntax"}
    end
  end

  defp merge_datasets(meta_header_dataset, instance_dataset) do
    # Merge elements
    elements = Map.merge(instance_dataset.elements, meta_header_dataset.elements)

    # Merge warnings
    warnings = (meta_header_dataset.warnings || []) ++ (instance_dataset.warnings || [])

    %{instance_dataset | elements: elements, warnings: warnings}
  end

  defp read_dataset(meta_header_dataset) do
    with {:ok, transfer_syntax} <- read_transfer_syntax(meta_header_dataset),
         explicit = is_explicit?(transfer_syntax),
         {:ok, byte_stream} <-
           get_dataset_byte_stream(
             transfer_syntax,
             meta_header_dataset.position,
             meta_header_dataset.byte_array,
             []
           ) do
      dataset =
        DataSet.new(
          byte_stream.byte_array_parser,
          byte_stream.byte_array,
          %{}
        )
        |> Map.put(:warnings, byte_stream.warnings)

      if explicit do
        DicomDataSet.parse_explicit(
          dataset,
          byte_stream,
          byte_size(byte_stream.byte_array)
        )
      else
        DicomDataSet.parse_implicit(
          dataset,
          byte_stream,
          byte_size(byte_stream.byte_array)
        )
      end
    end
  end
end
