defmodule ExDicom.Alloc do
  @moduledoc """
  Module containing helper functions for working with binary data in DICOM parsing.
  """

  @doc """
  Creates a new binary of the specified length filled with zeros.

  ## Parameters
    * length - The desired length of the new binary in bytes

  ## Returns
    * {:ok, binary} - A new zero-filled binary of the specified length
    * {:error, String.t()} - Error message if the input is invalid

  ## Examples
      iex> ExDicom.Alloc.zeros(3)
      {:ok, <<0, 0, 0>>}
  """
  @spec zeros(non_neg_integer()) :: {:ok, binary()} | {:error, String.t()}
  def zeros(length) when is_integer(length) and length >= 0 do
    try do
      # Create a binary filled with zeros of the specified length
      result = :binary.copy(<<0>>, length)
      {:ok, result}
    rescue
      ArgumentError ->
        {:error, "Invalid length specified"}
    end
  end

  def zeros(_invalid_length) do
    {:error, "Length must be a non-negative integer"}
  end
end
