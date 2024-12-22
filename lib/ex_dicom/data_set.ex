defmodule ExDicom.DataSet do
  @moduledoc """
  Encapsulates a collection of DICOM Elements and provides various functions to access the data.

  Rules for handling padded spaces:
  - DS = Strip leading and trailing spaces
  - DT = Strip trailing spaces
  - IS = Strip leading and trailing spaces
  - PN = Strip trailing spaces
  - TM = Strip trailing spaces
  - AE = Strip leading and trailing spaces
  - CS = Strip leading and trailing spaces
  - SH = Strip leading and trailing spaces
  - LO = Strip leading and trailing spaces
  - LT = Strip trailing spaces
  - ST = Strip trailing spaces
  - UT = Strip trailing spaces
  """
  alias ExDicom.ByteArrayParser

  defstruct [:byte_array_parser, :byte_array, :elements, :warnings, :position]

  @type parser :: module()
  @type byte_array :: binary()
  @type elements :: %{String.t() => element()}
  @type element :: %{
          data_offset: non_neg_integer(),
          length: non_neg_integer(),
          parser: parser() | nil,
          Value: any() | nil
        }
  @type t :: %__MODULE__{
          byte_array_parser: parser(),
          byte_array: byte_array(),
          elements: elements()
        }
  @type tag :: String.t()
  @type index :: non_neg_integer()

  @doc """
  Creates a new DicomDataset struct.
  """
  @spec new(parser(), byte_array(), elements()) :: t()
  def new(byte_array_parser, byte_array, elements) do
    %__MODULE__{
      byte_array_parser: byte_array_parser,
      byte_array: byte_array,
      elements: elements
    }
  end

  @spec get_parser(element(), parser()) :: parser()
  defp get_parser(element, default_parser) do
    Map.get(element, :parser, default_parser)
  end

  @doc """
  Finds the element for tag and returns an unsigned int 16 if it exists and has data.
  """
  @spec uint16(t(), tag(), index()) :: integer() | nil
  def uint16(dataset, tag, index \\ 0) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length != 0 do
      parser = get_parser(element, dataset.byte_array_parser)

      value = parser.read_uint16(dataset.byte_array, element.data_offset + index * 2)

      case value do
        {:ok, val} -> val
        {:error, _} -> nil
        val when is_integer(val) -> val
      end
    else
      _ -> nil
    end
  end

  @doc """
  Finds the element for tag and returns a signed int 16 if it exists and has data.
  """
  @spec int16(t(), tag(), index()) :: integer() | nil
  def int16(dataset, tag, index \\ 0) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length != 0 do
      parser = get_parser(element, dataset.byte_array_parser)
      value = parser.read_int16(dataset.byte_array, element.data_offset + index * 2)

      case value do
        {:ok, val} -> val
        {:error, _} -> nil
        val when is_integer(val) -> val
      end
    else
      _ -> nil
    end
  end

  @doc """
  Finds the element for tag and returns an unsigned int 32 if it exists and has data.
  """
  @spec uint32(t(), tag(), index()) :: integer() | nil
  def uint32(dataset, tag, index \\ 0) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length != 0 do
      parser = get_parser(element, dataset.byte_array_parser)
      value = parser.read_uint32(dataset.byte_array, element.data_offset + index * 4)

      case value do
        {:ok, val} -> val
        {:error, _} -> nil
        val when is_integer(val) -> val
      end
    else
      _ -> nil
    end
  end

  @doc """
  Finds the element for tag and returns a signed int 32 if it exists and has data.
  """
  @spec int32(t(), tag(), index()) :: integer() | nil
  def int32(dataset, tag, index \\ 0) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length != 0 do
      parser = get_parser(element, dataset.byte_array_parser)
      value = parser.read_int32(dataset.byte_array, element.data_offset + index * 4)

      case value do
        {:ok, val} -> val
        {:error, _} -> nil
        val when is_integer(val) -> val
      end
    else
      _ -> nil
    end
  end

  @doc """
  Finds the element for tag and returns a 32-bit float if it exists and has data.
  """
  @spec float(t(), tag(), index()) :: float() | nil
  def float(dataset, tag, index \\ 0) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length != 0 do
      parser = get_parser(element, dataset.byte_array_parser)
      value = parser.read_float(dataset.byte_array, element.data_offset + index * 4)

      case value do
        {:ok, val} -> val
        {:error, _} -> nil
        val when is_float(val) -> val
      end
    else
      _ -> nil
    end
  end

  @doc """
  Finds the element for tag and returns a 64-bit float if it exists and has data.
  """
  @spec double(t(), tag(), index()) :: float() | nil
  def double(dataset, tag, index \\ 0) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length != 0 do
      parser = get_parser(element, dataset.byte_array_parser)
      value = parser.read_double(dataset.byte_array, element.data_offset + index * 8)

      case value do
        {:ok, val} -> val
        {:error, _} -> nil
        val when is_float(val) -> val
      end
    else
      _ -> nil
    end
  end

  @doc """
  Returns the number of string values for the element.
  """
  @spec num_string_values(t(), tag()) :: integer() | nil
  def num_string_values(dataset, tag) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length > 0,
         {:ok, fixed_string} <-
           ByteArrayParser.read_fixed_string(
             dataset.byte_array,
             element.data_offset,
             element.length
           ) do
      case String.split(fixed_string, "\\") do
        [] -> nil
        parts -> length(parts)
      end
    else
      _ -> nil
    end
  end

  @doc """
  Returns a string for the element. For VR types of AE, CS, SH and LO.
  If index is provided, returns the component at that index in a multi-valued string.
  """
  @spec string(t(), tag(), integer() | nil) :: String.t() | nil
  def string(dataset, tag, index \\ nil) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag) do
      cond do
        not is_nil(element["Value"]) ->
          element["Value"]

        element.length > 0 ->
          with {:ok, fixed_string} <-
                 ByteArrayParser.read_fixed_string(
                   dataset.byte_array,
                   element.data_offset,
                   element.length
                 ) do
            if is_integer(index) do
              fixed_string
              |> String.split("\\")
              |> Enum.at(index)
              |> case do
                nil -> nil
                value -> String.trim(value)
              end
            else
              String.trim(fixed_string)
            end
          else
            _ -> nil
          end

        true ->
          nil
      end
    else
      _ -> nil
    end
  end

  @doc """
  Returns a string with leading spaces preserved and trailing spaces removed.
  For VRs of type UT, ST and LT.
  """
  @spec text(t(), tag(), integer() | nil) :: String.t() | nil
  def text(dataset, tag, index \\ nil) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length > 0,
         {:ok, fixed_string} <-
           ByteArrayParser.read_fixed_string(
             dataset.byte_array,
             element.data_offset,
             element.length
           ) do
      if is_integer(index) do
        fixed_string
        |> String.split("\\")
        |> Enum.at(index)
        |> case do
          nil -> nil
          value -> String.replace(value, ~r/\s+$/, "")
        end
      else
        String.replace(fixed_string, ~r/\s+$/, "")
      end
    else
      _ -> nil
    end
  end

  @doc """
  Parses a string to a float for the specified index in a multi-valued element.
  """
  @spec float_string(t(), tag(), integer() | nil) :: float() | nil
  def float_string(dataset, tag, index \\ 0) do
    case string(dataset, tag, index) do
      nil ->
        nil

      value ->
        case Float.parse(value) do
          {float_val, _} -> float_val
          :error -> nil
        end
    end
  end

  @doc """
  Parses a string to an integer for the specified index in a multi-valued element.
  """
  @spec int_string(t(), tag(), integer() | nil) :: integer() | nil
  def int_string(dataset, tag, index \\ 0) do
    case string(dataset, tag, index) do
      nil ->
        nil

      value ->
        case Integer.parse(value) do
          {int_val, _} -> int_val
          :error -> nil
        end
    end
  end

  @doc """
  Parses an element tag according to the 'AT' VR definition.
  """
  @spec attribute_tag(t(), tag()) :: String.t() | nil
  def attribute_tag(dataset, tag) do
    with element when not is_nil(element) <- Map.get(dataset.elements, tag),
         true <- element.length == 4,
         parser = get_parser(element, dataset.byte_array_parser),
         {:ok, value1} <- parser.read_uint16(dataset.byte_array, element.data_offset),
         {:ok, value2} <- parser.read_uint16(dataset.byte_array, element.data_offset + 2) do
      tag_value = value1 * 256 * 256 + value2
      "x#{String.pad_leading(Integer.to_string(tag_value, 16), 8, "0")}"
    else
      _ -> nil
    end
  end
end
