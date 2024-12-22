defmodule ExDicom do
  @moduledoc """
  Main module for DICOM file parsing functionality.
  """

  alias ExDicom.DataSet
  alias ExDicom.Parser

  @doc """
  Parses a DICOM file from the given file path.

  ## Parameters
    * file_path - Path to the DICOM file to parse

  ## Returns
    * {:ok, dataset} - Successfully parsed DICOM data
    * {:error, reason} - Error occurred during parsing

  ## Examples
      iex> {:error, message} = ExDicom.parse_file("non_existent.dcm")
      iex> is_binary(message)
      true
  """
  @spec parse_file(String.t()) :: {:ok, DataSet.t()} | {:error, String.t()}
  def parse_file(file_path) do
    with {:ok, binary} <- File.read(file_path),
         {:ok, dataset} <- Parser.parse_dicom(binary) do
      {:ok, dataset}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, posix_error} ->
        {:error, "Failed to read file: #{inspect(posix_error)}"}
    end
  end
end
