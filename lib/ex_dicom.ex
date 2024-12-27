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
    * `{:ok, dataset}` - Successfully parsed DICOM data
    * `{:error, reason}` - Error occurred during parsing

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

  @doc """
  Writes a DICOM dataset to a file at the specified path.

  ## Parameters
    * dataset - The DICOM dataset to write
    * file_path - Path where the DICOM file should be written

  ## Returns
    * `:ok` - Successfully wrote DICOM data
    * `{:error, reason}` - Error occurred during writing

  ## Examples
        iex> {:ok, dataset} = ExDicom.parse_file("test/fixtures/brain.dcm")
        iex> path = "test/fixtures/output.dcm"
        iex> result = ExDicom.write_file(dataset, path)
        iex> File.rm!(path)
        iex> result
        :ok
  """
  @spec write_file(DataSet.t(), String.t()) :: :ok | {:error, String.t()}
  def write_file(%DataSet{} = dataset, file_path) when is_binary(file_path) do
    case File.write(file_path, dataset.byte_array) do
      :ok -> :ok
      {:error, posix_error} -> {:error, "Failed to write file: #{inspect(posix_error)}"}
    end
  end

  def write_file(nil, _file_path), do: {:error, "Dataset cannot be nil"}
  def write_file(_dataset, nil), do: {:error, "File path cannot be nil"}
end
