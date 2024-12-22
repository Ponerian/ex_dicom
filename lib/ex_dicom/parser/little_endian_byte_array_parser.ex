defmodule ExDicom.Parser.LittleEndianByteArrayParser do
  @moduledoc """
  Internal helper functions for parsing different types from a little-endian byte array
  """

  @doc """
  Parses an unsigned int 16 from a little-endian byte array

  ## Parameters
    - byte_array: the byte array to read from
    - position: the position in the byte array to read from

  ## Returns
    The parsed unsigned int 16

  ## Raises
    ArgumentError if buffer overread would occur
  """
  def read_uint16(byte_array, position) when position >= 0 do
    if position + 2 > byte_size(byte_array) do
      raise ArgumentError, "attempt to read past end of buffer"
    end

    <<_::binary-size(position), value::little-unsigned-16, _::binary>> = byte_array
    value
  end

  def read_uint16(_, _), do: raise(ArgumentError, "position cannot be less than 0")

  @doc """
  Parses a signed int 16 from a little-endian byte array
  """
  def read_int16(byte_array, position) when position >= 0 do
    if position + 2 > byte_size(byte_array) do
      raise ArgumentError, "attempt to read past end of buffer"
    end

    <<_::binary-size(position), value::little-signed-16, _::binary>> = byte_array
    value
  end

  def read_int16(_, _), do: raise(ArgumentError, "position cannot be less than 0")

  @doc """
  Parses an unsigned int 32 from a little-endian byte array
  """
  def read_uint32(byte_array, position) when position >= 0 do
    if position + 4 > byte_size(byte_array) do
      raise ArgumentError, "attempt to read past end of buffer"
    end

    <<_::binary-size(position), value::little-unsigned-32, _::binary>> = byte_array
    value
  end

  def read_uint32(_, _), do: raise(ArgumentError, "position cannot be less than 0")

  @doc """
  Parses a signed int 32 from a little-endian byte array
  """
  def read_int32(byte_array, position) when position >= 0 do
    if position + 4 > byte_size(byte_array) do
      raise ArgumentError, "attempt to read past end of buffer"
    end

    <<_::binary-size(position), value::little-signed-32, _::binary>> = byte_array
    value
  end

  def read_int32(_, _), do: raise(ArgumentError, "position cannot be less than 0")

  @doc """
  Parses 32-bit float from a little-endian byte array
  """
  def read_float(byte_array, position) when position >= 0 do
    if position + 4 > byte_size(byte_array) do
      raise ArgumentError, "attempt to read past end of buffer"
    end

    <<_::binary-size(position), value::little-float-32, _::binary>> = byte_array
    value
  end

  def read_float(_, _), do: raise(ArgumentError, "position cannot be less than 0")

  @doc """
  Parses 64-bit float from a little-endian byte array
  """
  def read_double(byte_array, position) when position >= 0 do
    if position + 8 > byte_size(byte_array) do
      raise ArgumentError, "attempt to read past end of buffer"
    end

    <<_::binary-size(position), value::little-float-64, _::binary>> = byte_array
    value
  end

  def read_double(_, _), do: raise(ArgumentError, "position cannot be less than 0")
end
