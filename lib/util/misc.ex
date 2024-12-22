defmodule ExDicom.Util.Misc do
  @moduledoc """
  Utility functions for DICOM parsing and data handling.
  """

  @string_vrs %{
    "AE" => true,
    "AS" => true,
    "AT" => false,
    "CS" => true,
    "DA" => true,
    "DS" => true,
    "DT" => true,
    "FL" => false,
    "FD" => false,
    "IS" => true,
    "LO" => true,
    "LT" => true,
    "OB" => false,
    "OD" => false,
    "OF" => false,
    "OW" => false,
    "PN" => true,
    "SH" => true,
    "SL" => false,
    "SQ" => false,
    "SS" => false,
    "ST" => true,
    "TM" => true,
    "UI" => true,
    "UL" => false,
    # undefined in original
    "UN" => nil,
    "UR" => true,
    "US" => false,
    "UT" => true
  }

  @typedoc """
  Type representing a parsed person name with standard DICOM components.
  """
  @type person_name :: %{
          family_name: String.t() | nil,
          given_name: String.t() | nil,
          middle_name: String.t() | nil,
          prefix: String.t() | nil,
          suffix: String.t() | nil
        }

  @doc """
  Tests if the given VR (Value Representation) is a string type.

  ## Parameters

    * vr - The VR code to test

  ## Returns

    * `true` if string type
    * `false` if not string type
    * `nil` if unknown VR or UN type

  ## Examples

      iex> ExDicom.Util.string_vr?("PN")
      true

      iex> ExDicom.Util.string_vr?("UN")
      nil
  """
  @spec string_vr?(String.t()) :: boolean() | nil
  def string_vr?(vr) when is_binary(vr) do
    Map.get(@string_vrs, vr)
  end

  def string_vr?(_), do: nil

  @doc """
  Tests if a given tag in the format xggggeeee is a private tag.
  Private tags are identified by having an odd group number.

  ## Parameters

    * tag - The DICOM tag in format xggggeeee

  ## Returns

    * `true` if the tag is private
    * `false` if the tag is not private

  ## Raises

    * RuntimeError if the fourth character of the tag cannot be parsed as hex

  ## Examples

      iex> ExDicom.Util.private_tag?("x00090010")
      true

      iex> ExDicom.Util.private_tag?("x00080010")
      false
  """
  @spec private_tag?(String.t()) :: boolean()
  def private_tag?(tag) when is_binary(tag) do
    case Integer.parse(String.at(tag, 4), 16) do
      {last_group_digit, _} ->
        rem(last_group_digit, 2) == 1

      _ ->
        raise "ExDicom.Util.private_tag?: cannot parse last character of group"
    end
  end

  @doc """
  Parses a PN (Person Name) formatted string into a map with standardized name components.

  ## Parameters

    * person_name - A string in the PN VR format (components separated by ^)

  ## Returns

    * A map with :family_name, :given_name, :middle_name, :prefix, and :suffix keys
    * `nil` if input is nil

  ## Examples

      iex> ExDicom.Util.parse_pn("Smith^John^A^Dr^Jr")
      %{
        family_name: "Smith",
        given_name: "John",
        middle_name: "A",
        prefix: "Dr",
        suffix: "Jr"
      }

      iex> ExDicom.Util.parse_pn(nil)
      nil
  """
  @spec parse_pn(String.t() | nil) :: person_name() | nil
  def parse_pn(nil), do: nil

  def parse_pn(person_name) when is_binary(person_name) do
    [family_name, given_name, middle_name, prefix, suffix | _rest] =
      String.split(person_name, "^", parts: 5, trim: false) ++ List.duplicate(nil, 5)

    %{
      family_name: empty_to_nil(family_name),
      given_name: empty_to_nil(given_name),
      middle_name: empty_to_nil(middle_name),
      prefix: empty_to_nil(prefix),
      suffix: empty_to_nil(suffix)
    }
  end

  # Helper function to convert empty strings to nil
  defp empty_to_nil(""), do: nil
  defp empty_to_nil(string), do: string
end
