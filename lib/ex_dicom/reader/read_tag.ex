defmodule ExDicom.Reader.ReadTag do
  @moduledoc """
  Provides a function to read a DICOM tag (group + element) from a ByteStream.

  Corresponds to the JavaScript function:

      export default function readTag(byteStream) {
        if (byteStream === undefined) {
          throw 'dicomParser.readTag: missing required parameter \'byteStream\'';
        }

        const groupNumber = byteStream.readUint16() * 256 * 256;
        const elementNumber = byteStream.readUint16();
        const tag = `x${("00000000" + (groupNumber + elementNumber).toString(16)).substr(-8)}`;

        return tag;
      }
  """

  alias ExDicom.ByteStream

  @doc """
  Reads a tag (group number and element number) from a ByteStream, returning
  the tag in the format `xggggeeee` where `gggg` and `eeee` are lowercase hex.

  ## Examples

      iex> {:ok, tag, updated_stream} = ExDicom.ReadTag.read_tag(stream)
      iex> tag
      "x00080020"

  Returns:
    * `{:ok, tag_string, updated_stream}` on success
    * `{:error, reason}` if there's a problem (e.g. missing stream)
  """
  @spec read_tag(ByteStream.t() | nil) :: {:ok, String.t(), ByteStream.t()} | {:error, String.t()}
  def read_tag(nil), do: {:error, "dicomParser.readTag: missing required parameter 'byteStream'"}

  def read_tag(byte_stream) do
    with {:ok, group_number, stream_after_group} <- ByteStream.read_uint16(byte_stream),
         {:ok, element_number, stream_after_element} <- ByteStream.read_uint16(stream_after_group) do
      total = group_number * 65_536 + element_number

      # Convert to lowercase hex, zero-pad to 8 digits, then prepend "x"
      hex_str = total |> Integer.to_string(16) |> String.pad_leading(8, "0")
      tag = "x#{hex_str}"

      {:ok, tag, stream_after_element}
    end
  end
end
