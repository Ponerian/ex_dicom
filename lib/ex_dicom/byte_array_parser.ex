defmodule ExDicom.ByteArrayParser do
  @moduledoc """
  Internal helper functions common to parsing byte arrays of any type.
  """

  @doc """
  Reads a string of 8-bit characters from a binary and returns the parsed string.
  A null terminator will end the string but will not affect the length parameter.
  Trailing and leading spaces are preserved (not trimmed).

  ## Parameters
    * byte_array - The binary to read from
    * position - The position in the binary to read from
    * length - The maximum number of bytes to parse

  ## Returns
    * `{:ok, string}` - The parsed string
    * `{:error, string}` - Error message if reading fails

  ## Examples
      iex> ByteArrayParser.read_fixed_string(<<65, 66, 67, 0, 68>>, 0, 4)
      {:ok, "ABC"}

      iex> ByteArrayParser.read_fixed_string(<<65, 66, 67>>, 0, 5)
      {:error, "dicomParser.readFixedString: attempt to read past end of buffer"}

      iex> ByteArrayParser.read_fixed_string(<<32, 65, 66, 32>>, 0, 4)
      {:ok, " AB "}
  """
  @spec read_fixed_string(binary(), non_neg_integer(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  def read_fixed_string(_byte_array, _position, length) when length < 0 do
    {:error, "dicomParser.readFixedString - length cannot be less than 0"}
  end

  def read_fixed_string(byte_array, position, length)
      when position + length > byte_size(byte_array) do
    {:error, "dicomParser.readFixedString: attempt to read past end of buffer"}
  end

  def read_fixed_string(byte_array, position, length) do
    # Extract the slice we're interested in
    slice = binary_part(byte_array, position, length)

    # Convert to a list of bytes and process until null terminator or end
    result =
      slice
      |> :binary.bin_to_list()
      |> Enum.reduce_while("", fn
        0, acc -> {:halt, acc}
        byte, acc -> {:cont, acc <> <<byte::utf8>>}
      end)

    {:ok, result}
  end

  @doc """
  Same as read_fixed_string/3 but raises on error.

  ## Examples
      iex> ByteArrayParser.read_fixed_string!(<<65, 66, 67, 0, 68>>, 0, 4)
      "ABC"

      iex> ByteArrayParser.read_fixed_string!(<<65, 66, 67>>, 0, 5)
      ** (RuntimeError) dicomParser.readFixedString: attempt to read past end of buffer
  """
  @spec read_fixed_string!(binary(), non_neg_integer(), integer()) :: String.t()
  def read_fixed_string!(byte_array, position, length) do
    case read_fixed_string(byte_array, position, length) do
      {:ok, result} -> result
      {:error, message} -> raise message
    end
  end

  @doc """
  A more efficient version of read_fixed_string that operates directly on binaries
  without converting to lists. However, it will read the full length even after
  encountering a null terminator.

  This is useful when you know your string won't contain null terminators
  or when you want to process the full binary segment regardless.

  ## Examples
      iex> ByteArrayParser.read_fixed_string_fast(<<65, 66, 67, 68>>, 0, 4)
      {:ok, "ABCD"}
  """
  @spec read_fixed_string_fast(binary(), non_neg_integer(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  def read_fixed_string_fast(_byte_array, _position, length) when length < 0 do
    {:error, "dicomParser.readFixedString - length cannot be less than 0"}
  end

  def read_fixed_string_fast(byte_array, position, length)
      when position + length > byte_size(byte_array) do
    {:error, "dicomParser.readFixedString: attempt to read past end of buffer"}
  end

  def read_fixed_string_fast(byte_array, position, length) do
    result = binary_part(byte_array, position, length)
    {:ok, result}
  end
end
