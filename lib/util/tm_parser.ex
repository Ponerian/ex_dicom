defmodule ExDicom.Util.TMParser do
  @moduledoc """
  Parses TM formatted strings into a map with time components.
  The TM format expects strings in the format HHMMSS.FFFFFF where:
  - HH represents hours (00-23)
  - MM represents minutes (00-59)
  - SS represents seconds (00-59)
  - FFFFFF represents fractional seconds (000000-999999)
  """

  @type time_components :: %{
          hours: integer(),
          minutes: integer() | nil,
          seconds: integer() | nil,
          fractional_seconds: integer() | nil
        }

  @doc """
  Parses a TM formatted string into a map with time components.

  ## Parameters
    * time - String in TM VR format
    * validate - Boolean indicating whether to validate the time components

  ## Returns
    * `{:ok, map}` with time components if valid
    * `{:error, string}` with error message if invalid and validate is true
    * `{:ok, nil}` if input is invalid and validate is false

  ## Examples
      iex> TMParser.parse("14")
      {:ok, %{hours: 14, minutes: nil, seconds: nil, fractional_seconds: nil}}

      iex> TMParser.parse("1430")
      {:ok, %{hours: 14, minutes: 30, seconds: nil, fractional_seconds: nil}}

      iex> TMParser.parse("143022.123")
      {:ok, %{hours: 14, minutes: 30, seconds: 22, fractional_seconds: 123000}}

      iex> TMParser.parse("24", true)
      {:error, "invalid TM '24'"}
  """
  @spec parse(String.t(), boolean()) :: {:ok, time_components() | nil} | {:error, String.t()}
  def parse(time, validate \\ false)

  def parse(time, validate) when byte_size(time) >= 2 do
    with {:ok, components} <- extract_components(time),
         true <- valid_components?(components) or !validate do
      {:ok, components}
    else
      false -> {:error, "invalid TM '#{time}'"}
    end
  end

  def parse(time, true), do: {:error, "invalid TM '#{time}'"}
  def parse(_time, false), do: {:ok, nil}

  defp extract_components(<<hours::binary-size(2)>> <> rest) do
    with {hours, ""} <- Integer.parse(hours) do
      components = %{
        hours: hours,
        minutes: nil,
        seconds: nil,
        fractional_seconds: nil
      }

      case rest do
        <<>> ->
          {:ok, components}

        <<minutes::binary-size(2)>> <> rest ->
          extract_minutes(minutes, rest, components)

        _ ->
          {:ok, components}
      end
    else
      _ -> {:ok, nil}
    end
  end

  defp extract_minutes(minutes, rest, components) do
    with {minutes, ""} <- Integer.parse(minutes) do
      components = Map.put(components, :minutes, minutes)

      case rest do
        <<>> ->
          {:ok, components}

        <<seconds::binary-size(2)>> <> rest ->
          extract_seconds(seconds, rest, components)

        _ ->
          {:ok, components}
      end
    else
      _ -> {:ok, nil}
    end
  end

  defp extract_seconds(seconds, rest, components) do
    with {seconds, ""} <- Integer.parse(seconds) do
      components = Map.put(components, :seconds, seconds)

      case rest do
        <<>> ->
          {:ok, components}

        <<".", fractional::binary>> ->
          extract_fractional_seconds(fractional, components)

        _ ->
          {:ok, components}
      end
    else
      _ -> {:ok, nil}
    end
  end

  defp extract_fractional_seconds(fractional, components) do
    # Pad or truncate to 6 digits
    fractional = String.pad_trailing(fractional, 6, "0")
    fractional = binary_part(fractional, 0, 6)

    case Integer.parse(fractional) do
      {fractional, ""} ->
        components = Map.put(components, :fractional_seconds, fractional)
        {:ok, components}

      _ ->
        {:ok, nil}
    end
  end

  defp valid_components?(%{
         hours: hours,
         minutes: minutes,
         seconds: seconds,
         fractional_seconds: fractional
       }) do
    valid_hours?(hours) and
      valid_minutes?(minutes) and
      valid_seconds?(seconds) and
      valid_fractional?(fractional)
  end

  defp valid_hours?(hours) when is_integer(hours) and hours >= 0 and hours <= 23, do: true
  defp valid_hours?(_), do: false

  defp valid_minutes?(nil), do: true

  defp valid_minutes?(minutes) when is_integer(minutes) and minutes >= 0 and minutes <= 59,
    do: true

  defp valid_minutes?(_), do: false

  defp valid_seconds?(nil), do: true

  defp valid_seconds?(seconds) when is_integer(seconds) and seconds >= 0 and seconds <= 59,
    do: true

  defp valid_seconds?(_), do: false

  defp valid_fractional?(nil), do: true

  defp valid_fractional?(fractional)
       when is_integer(fractional) and
              fractional >= 0 and fractional <= 999_999,
       do: true

  defp valid_fractional?(_), do: false
end
