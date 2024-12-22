defmodule ExDicom.ByteAllocator do
  @moduledoc """
  Provides functionality for allocating byte arrays (binaries) of specified lengths.
  """

  @type byte_array :: binary()

  @doc """
  Creates a new binary of the specified length.

  ## Parameters
    * source - The source binary to determine the type
    * length - The desired length of the new binary in bytes

  ## Returns
    * {:ok, binary} - A new binary of the specified length filled with zeros
    * {:error, String.t()} - Error message if the input type is not supported

  ## Examples
      iex> ByteAllocator.alloc(<<1, 2, 3>>, 5)
      {:ok, <<0, 0, 0, 0, 0>>}

      iex> ByteAllocator.alloc("not a binary", 5)
      {:error, "unknown type for byte array"}
  """
  @spec alloc(term(), non_neg_integer()) :: {:ok, byte_array()} | {:error, String.t()}
  def alloc(source, length) when is_binary(source) and is_integer(length) and length >= 0 do
    {:ok, :binary.copy(<<0>>, length)}
  end

  def alloc(_source, _length) do
    {:error, "unknown type for byte array"}
  end
end
