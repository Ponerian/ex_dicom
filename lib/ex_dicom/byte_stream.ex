defmodule ExDicom.ByteStream do
  @moduledoc """
  Internal helper module to assist with parsing. Supports reading from a byte
  stream contained in a binary.

  Example usage:

      byte_array = <<1, 2, 3, 4>>
      {:ok, stream} = ByteStream.new(byte_array_parser, byte_array)
  """

  defstruct [
    :byte_array_parser,
    :byte_array,
    :position,
    warnings: []
  ]

  @type t :: %__MODULE__{
          byte_array_parser: module(),
          byte_array: binary(),
          position: non_neg_integer(),
          warnings: [String.t()]
        }

  @doc """
  Creates a new ByteStream struct.

  ## Parameters
    * byte_array_parser: module that implements parsing functions
    * byte_array: binary containing the byte stream
    * position: optional starting position (defaults to 0)

  ## Returns
    * `{:ok, stream}` if successful
    * `{:error, reason}` if validation fails
  """
  @spec new(module(), binary(), non_neg_integer()) :: {:ok, t()} | {:error, String.t()}
  def new(byte_array_parser, byte_array, position \\ 0)

  def new(nil, _byte_array, _position) do
    {:error, "ByteStream: missing required parameter 'byte_array_parser'"}
  end

  def new(_parser, nil, _position) do
    {:error, "ByteStream: missing required parameter 'byte_array'"}
  end

  def new(_parser, _byte_array, position) when position < 0 do
    {:error, "ByteStream: parameter 'position' cannot be less than 0"}
  end

  def new(_parser, byte_array, position) when position >= byte_size(byte_array) do
    {:error,
     "ByteStream: parameter 'position' cannot be greater than or equal to byte_array length"}
  end

  def new(byte_array_parser, byte_array, position) when is_binary(byte_array) do
    {:ok,
     %__MODULE__{
       byte_array_parser: byte_array_parser,
       byte_array: byte_array,
       position: position
     }}
  end

  @doc """
  Safely seeks through the byte stream. Returns error if attempt
  is made to seek outside of the byte array.

  ## Parameters
    * stream: ByteStream struct
    * offset: number of bytes to add to the position

  ## Returns
    * `{:ok, new_stream}` with updated position
    * `{:error, reason}` if seek would be invalid
  """
  @spec seek(t(), integer()) :: {:ok, t()} | {:error, String.t()}
  def seek(%__MODULE__{position: pos, byte_array: _array} = _stream, offset)
      when pos + offset < 0 do
    {:error, "ByteStream.seek: cannot seek to position < 0"}
  end

  def seek(%__MODULE__{position: pos, byte_array: array} = _stream, offset)
      when pos + offset > byte_size(array) do
    {:error, "ByteStream.seek: cannot seek beyond the end of the byte array"}
  end

  def seek(%__MODULE__{position: pos} = stream, offset) do
    {:ok, %{stream | position: pos + offset}}
  end

  @doc """
  Returns a new ByteStream struct from the current position containing the requested number of bytes

  ## Parameters
    * stream: ByteStream struct
    * num_bytes: length of the binary for the new ByteStream

  ## Returns
    * `{:ok, new_stream}` containing the requested bytes
    * `{:error, reason}` if buffer overread would occur
  """
  @spec read_byte_stream(t(), non_neg_integer()) :: {:ok, t()} | {:error, String.t()}
  def read_byte_stream(%__MODULE__{} = stream, num_bytes) do
    case get_bytes(stream, num_bytes) do
      {:ok, bytes, _new_stream} ->
        {:ok,
         %__MODULE__{
           byte_array_parser: stream.byte_array_parser,
           byte_array: bytes,
           position: 0
         }}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Returns the current position in the byte array

  ## Parameters
    * stream: ByteStream struct

  ## Returns
    * current position in bytes
  """
  @spec get_position(t()) :: non_neg_integer()
  def get_position(%__MODULE__{position: pos}), do: pos

  @doc """
  Returns the size of the byte array

  ## Parameters
    * stream: ByteStream struct

  ## Returns
    * size of the byte array in bytes
  """
  @spec get_size(t()) :: non_neg_integer()
  def get_size(%__MODULE__{byte_array: array}), do: byte_size(array)

  @doc """
  Parses an unsigned int 16 from the byte array and advances the position by 2 bytes

  ## Parameters
    * stream: ByteStream struct

  ## Returns
    * `{:ok, value, new_stream}` with parsed uint16 and updated position
    * `{:error, reason}` if buffer overread would occur
  """
  @spec read_uint16(t()) :: {:ok, non_neg_integer(), t()} | {:error, String.t()}
  def read_uint16(%__MODULE__{} = stream) do
    case get_bytes(stream, 2) do
      {:ok, <<value::unsigned-little-16>>, new_stream} ->
        {:ok, value, new_stream}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Parses an unsigned int 32 from the byte array and advances the position by 4 bytes

  ## Parameters
    * stream: ByteStream struct

  ## Returns
    * `{:ok, value, new_stream}` with parsed uint32 and updated position
    * `{:error, reason}` if buffer overread would occur
  """
  @spec read_uint32(t()) :: {:ok, non_neg_integer(), t()} | {:error, String.t()}
  def read_uint32(%__MODULE__{} = stream) do
    case get_bytes(stream, 4) do
      {:ok, <<value::unsigned-little-32>>, new_stream} ->
        {:ok, value, new_stream}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Reads a string of 8-bit characters up to the specified length or null terminator

  ## Parameters
    * stream: ByteStream struct
    * length: maximum number of bytes to parse

  ## Returns
    * `{:ok, string, new_stream}` with parsed string and updated position
    * `{:error, reason}` if buffer overread would occur
  """
  @spec read_fixed_string(t(), non_neg_integer()) :: {:ok, String.t(), t()} | {:error, String.t()}
  def read_fixed_string(%__MODULE__{} = stream, length) do
    case get_bytes(stream, length) do
      {:ok, bytes, new_stream} ->
        # Convert to string and trim at null terminator
        string =
          bytes
          |> :binary.bin_to_list()
          |> Enum.take_while(&(&1 != 0))
          |> List.to_string()

        {:ok, string, new_stream}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Adds a warning message to the ByteStream's warnings list.

  ## Parameters
    * stream: ByteStream struct
    * warning: warning message to add

  ## Returns
    * updated ByteStream struct with new warning added to warnings list
  """
  @spec add_warning(t(), String.t()) :: t()
  def add_warning(%__MODULE__{warnings: warnings} = stream, warning) when is_binary(warning) do
    %{stream | warnings: warnings ++ [warning]}
  end

  # Private helper to safely get bytes from current position
  @spec get_bytes(t(), non_neg_integer()) :: {:ok, binary(), t()} | {:error, String.t()}
  defp get_bytes(%__MODULE__{byte_array: array, position: pos} = stream, num_bytes) do
    file_size = byte_size(array)

    if pos + num_bytes > byte_size(array) do
      {:error,
       "ByteStream: buffer overread while attempting to read #{num_bytes} bytes at position #{pos}/#{file_size}"}
    else
      bytes = binary_part(array, pos, num_bytes)
      new_stream = %{stream | position: pos + num_bytes}
      {:ok, bytes, new_stream}
    end
  end
end
