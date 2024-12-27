defmodule ExDicomTest do
  use ExUnit.Case
  doctest ExDicom

  describe "parse_file/1" do
    test "returns error for non-existent file" do
      result = ExDicom.parse_file("non_existent.dcm")
      assert {:error, message} = result
      assert message =~ "Failed to read file"
    end

    test "returns error for invalid DICOM file" do
      path = "test/fixtures/invalid.dcm"
      File.write!(path, "not a DICOM file")

      result = ExDicom.parse_file(path)
      assert {:error, _message} = result

      File.rm!(path)
    end

    test "successfully parses a valid DICOM file" do
      path = "test/fixtures/brain.dcm"
      result = ExDicom.parse_file(path)
      assert {:ok, dataset} = result
      assert %ExDicom.DataSet{} = dataset

      assert is_map(dataset.elements)
      assert is_binary(dataset.byte_array)
      refute is_nil(dataset.byte_array_parser)
    end

    test "correctly parses specific DICOM attributes" do
      {:ok, dataset} = ExDicom.parse_file("test/fixtures/brain.dcm")

      # Patient Name
      assert dataset.elements["x00100010"]
      # Modality
      assert dataset.elements["x00080060"]
      # Rows
      assert dataset.elements["x00280010"]
      # Columns
      assert dataset.elements["x00280011"]

      assert is_integer(ExDicom.DataSet.uint16(dataset, "x00280010"))
      assert is_binary(ExDicom.DataSet.string(dataset, "x00080060"))
    end

    test "validates transfer syntax" do
      {:ok, dataset} = ExDicom.parse_file("test/fixtures/brain.dcm")
      transfer_syntax = dataset.elements["x00020010"]

      assert transfer_syntax
      value = ExDicom.DataSet.string(dataset, "x00020010")
      assert is_binary(value)
    end

    test "Read i120" do
      {:ok, dataset} = ExDicom.parse_file("test/fixtures/N2D_0003.dcm")
      transfer_syntax = dataset.elements["x00020010"]

      assert transfer_syntax
      value = ExDicom.DataSet.string(dataset, "x00020010")
      assert is_binary(value)
    end
  end
end
