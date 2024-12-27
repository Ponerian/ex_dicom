defmodule ExDicom.SharedCopy do
  @moduledoc """
  Module containing helper functions for working with binary data in DICOM parsing.
  """

  @doc """
  Creates a binary slice of the input binary data.

  ## Parameters
    * binary - The input binary data
    * byte_offset - Offset into the binary to start the slice
    * length - Number of bytes to include in the slice

  ## Returns
    * `{:ok, binary}` - A binary slice sharing the same underlying memory
    * `{:error, String.t()}` - Error message if the input is invalid

  ## Examples
      iex> DicomParser.copy(<<1, 2, 3, 4>>, 1, 2)
      {:ok, <<2, 3>>}
  """
  @spec copy(binary(), non_neg_integer(), non_neg_integer()) ::
          {:ok, binary()} | {:error, String.t()}
  def copy(binary, byte_offset, length) when is_binary(binary) do
    try do
      result = binary_part(binary, byte_offset, length)
      {:ok, result}
    rescue
      ArgumentError ->
        {:error, "Invalid offset or length for binary slice"}
    end
  end

  def copy(_non_binary, _byte_offset, _length) do
    {:error, "Input must be binary data"}
  end
end
