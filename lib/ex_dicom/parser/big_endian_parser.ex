defmodule ExDicom.Parser.BigEndianParser do
  @moduledoc """
  Provides functions for parsing different numeric types from a big-endian binary.
  All functions handle bounds checking and proper binary validation.
  """

  @typedoc "A binary string containing bytes to parse"
  @type byte_array :: binary()

  @typedoc "Position in the binary to start parsing from"
  @type position :: non_neg_integer()

  @doc """
  Parses an unsigned 16-bit integer from a big-endian binary.

  ## Parameters
    * byte_array - The binary to parse from
    * position - The position to start parsing from

  ## Returns
    * {:ok, integer} - The parsed unsigned 16-bit integer
    * {:error, String.t()} - Error message if parsing fails

  ## Examples
      iex> BigEndianParser.read_uint16(<<0x12, 0x34, 0x56>>, 0)
      {:ok, 0x1234}
  """
  @spec read_uint16(byte_array(), position()) :: {:ok, char()} | {:error, String.t()}
  def read_uint16(byte_array, position)
      when is_binary(byte_array) and is_integer(position) and position >= 0 do
    case byte_array do
      <<_::binary-size(position), value::big-unsigned-integer-size(16), _::binary>> ->
        {:ok, value}

      _ ->
        {:error, "bigEndianByteArrayParser.readUint16: attempt to read past end of buffer"}
    end
  end

  def read_uint16(_byte_array, position) when position < 0 do
    {:error, "bigEndianByteArrayParser.readUint16: position cannot be less than 0"}
  end

  @doc """
  Parses a signed 16-bit integer from a big-endian binary.

  ## Parameters
    * byte_array - The binary to parse from
    * position - The position to start parsing from

  ## Returns
    * {:ok, integer} - The parsed signed 16-bit integer
    * {:error, String.t()} - Error message if parsing fails

  ## Examples
      iex> BigEndianParser.read_int16(<<0xFF, 0xFE, 0x56>>, 0)
      {:ok, -2}
  """
  @spec read_int16(byte_array(), position()) :: {:ok, integer()} | {:error, String.t()}
  def read_int16(byte_array, position)
      when is_binary(byte_array) and is_integer(position) and position >= 0 do
    case byte_array do
      <<_::binary-size(position), value::big-signed-integer-size(16), _::binary>> ->
        {:ok, value}

      _ ->
        {:error, "bigEndianByteArrayParser.readInt16: attempt to read past end of buffer"}
    end
  end

  def read_int16(_byte_array, position) when position < 0 do
    {:error, "bigEndianByteArrayParser.readInt16: position cannot be less than 0"}
  end

  @doc """
  Parses an unsigned 32-bit integer from a big-endian binary.

  ## Parameters
    * byte_array - The binary to parse from
    * position - The position to start parsing from

  ## Returns
    * {:ok, integer} - The parsed unsigned 32-bit integer
    * {:error, String.t()} - Error message if parsing fails

  ## Examples
      iex> BigEndianParser.read_uint32(<<0x12, 0x34, 0x56, 0x78>>, 0)
      {:ok, 0x12345678}
  """
  @spec read_uint32(byte_array(), position()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def read_uint32(byte_array, position)
      when is_binary(byte_array) and is_integer(position) and position >= 0 do
    case byte_array do
      <<_::binary-size(position), value::big-unsigned-integer-size(32), _::binary>> ->
        {:ok, value}

      _ ->
        {:error, "bigEndianByteArrayParser.readUint32: attempt to read past end of buffer"}
    end
  end

  def read_uint32(_byte_array, position) when position < 0 do
    {:error, "bigEndianByteArrayParser.readUint32: position cannot be less than 0"}
  end

  @doc """
  Parses a signed 32-bit integer from a big-endian binary.

  ## Parameters
    * byte_array - The binary to parse from
    * position - The position to start parsing from

  ## Returns
    * {:ok, integer} - The parsed signed 32-bit integer
    * {:error, String.t()} - Error message if parsing fails

  ## Examples
      iex> BigEndianParser.read_int32(<<0xFF, 0xFF, 0xFF, 0xFE>>, 0)
      {:ok, -2}
  """
  @spec read_int32(byte_array(), position()) :: {:ok, integer()} | {:error, String.t()}
  def read_int32(byte_array, position)
      when is_binary(byte_array) and is_integer(position) and position >= 0 do
    case byte_array do
      <<_::binary-size(position), value::big-signed-integer-size(32), _::binary>> ->
        {:ok, value}

      _ ->
        {:error, "bigEndianByteArrayParser.readInt32: attempt to read past end of buffer"}
    end
  end

  def read_int32(_byte_array, position) when position < 0 do
    {:error, "bigEndianByteArrayParser.readInt32: position cannot be less than 0"}
  end

  @doc """
  Parses a 32-bit float from a big-endian binary.

  ## Parameters
    * byte_array - The binary to parse from
    * position - The position to start parsing from

  ## Returns
    * {:ok, float} - The parsed 32-bit float
    * {:error, String.t()} - Error message if parsing fails

  ## Examples
      iex> BigEndianParser.read_float(<<0x40, 0x48, 0xF5, 0xC3>>, 0)
      {:ok, 3.14}
  """
  @spec read_float(byte_array(), position()) :: {:ok, float()} | {:error, String.t()}
  def read_float(byte_array, position)
      when is_binary(byte_array) and is_integer(position) and position >= 0 do
    case byte_array do
      <<_::binary-size(position), value::big-float-size(32), _::binary>> ->
        {:ok, value}

      _ ->
        {:error, "bigEndianByteArrayParser.readFloat: attempt to read past end of buffer"}
    end
  end

  def read_float(_byte_array, position) when position < 0 do
    {:error, "bigEndianByteArrayParser.readFloat: position cannot be less than 0"}
  end

  @doc """
  Parses a 64-bit float from a big-endian binary.

  ## Parameters
    * byte_array - The binary to parse from
    * position - The position to start parsing from

  ## Returns
    * {:ok, float} - The parsed 64-bit float
    * {:error, String.t()} - Error message if parsing fails

  ## Examples
      iex> BigEndianParser.read_double(<<0x40, 0x09, 0x21, 0xFB, 0x54, 0x44, 0x2D, 0x18>>, 0)
      {:ok, 3.14159}
  """
  @spec read_double(byte_array(), position()) :: {:ok, float()} | {:error, String.t()}
  def read_double(byte_array, position)
      when is_binary(byte_array) and is_integer(position) and position >= 0 do
    case byte_array do
      <<_::binary-size(position), value::big-float-size(64), _::binary>> ->
        {:ok, value}

      _ ->
        {:error, "bigEndianByteArrayParser.readDouble: attempt to read past end of buffer"}
    end
  end

  def read_double(_byte_array, position) when position < 0 do
    {:error, "bigEndianByteArrayParser.readDouble: position cannot be less than 0"}
  end
end
