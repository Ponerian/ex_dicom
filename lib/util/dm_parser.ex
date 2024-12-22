defmodule ExDicom.Util.DAParser do
  @moduledoc """
  Parses DA formatted date strings into maps with date components.
  The DA format expects strings in the format YYYYMMDD where:
  - YYYY represents the year
  - MM represents the month (01-12)
  - DD represents the day (01-31, depending on month)
  """

  @type date_components :: %{
          year: integer(),
          month: integer(),
          day: integer()
        }

  @doc """
  Parses a DA formatted string into a map with date components.

  ## Parameters
    * date - String in DA format (YYYYMMDD)
    * validate - Boolean indicating whether to validate the date components

  ## Returns
    * {:ok, map} with date components if valid
    * {:error, string} with error message if invalid and validate is true
    * {:ok, nil} if input is invalid and validate is false

  ## Examples
      iex> DAParser.parse("20240131")
      {:ok, %{year: 2024, month: 1, day: 31}}

      iex> DAParser.parse("20240229")
      {:ok, %{year: 2024, month: 2, day: 29}}

      iex> DAParser.parse("20230229", true)
      {:error, "invalid DA '20230229'"}
  """
  @spec parse(String.t(), boolean()) :: {:ok, date_components() | nil} | {:error, String.t()}
  def parse(date, validate \\ false)

  def parse(date, validate) when is_binary(date) and byte_size(date) == 8 do
    with {:ok, components} <- extract_components(date),
         true <- valid_date?(components) or !validate do
      {:ok, components}
    else
      false -> {:error, "invalid DA '#{date}'"}
    end
  end

  def parse(date, true) when is_binary(date), do: {:error, "invalid DA '#{date}'"}
  def parse(_date, false), do: {:ok, nil}

  @doc """
  Returns the number of days in the given month for a specific year.

  ## Examples
      iex> DAParser.days_in_month(2, 2024)
      29

      iex> DAParser.days_in_month(2, 2023)
      28

      iex> DAParser.days_in_month(4, 2024)
      30
  """
  @spec days_in_month(integer(), integer()) :: integer()
  def days_in_month(month, year) when is_integer(month) and is_integer(year) do
    case month do
      2 -> if leap_year?(year), do: 29, else: 28
      month when month in [4, 6, 9, 11] -> 30
      _ -> 31
    end
  end

  defp extract_components(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    with {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {day, ""} <- Integer.parse(day) do
      {:ok,
       %{
         year: year,
         month: month,
         day: day
       }}
    else
      _ -> {:ok, nil}
    end
  end

  defp valid_date?(%{year: year, month: month, day: day}) when is_integer(year) do
    valid_month?(month) and valid_day?(day, month, year)
  end

  defp valid_date?(_), do: false

  defp valid_month?(month) when is_integer(month) and month > 0 and month <= 12, do: true
  defp valid_month?(_), do: false

  defp valid_day?(day, month, year) when is_integer(day) and day > 0 do
    day <= days_in_month(month, year)
  end

  defp valid_day?(_, _, _), do: false

  defp leap_year?(year) do
    (rem(year, 4) == 0 and rem(year, 100) != 0) or rem(year, 400) == 0
  end
end
