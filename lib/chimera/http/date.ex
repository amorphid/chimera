defmodule Chimera.HTTP.Date do
  alias Calendar.UTCOnlyTimeZoneDatabase

  @month_names %{
    1 => "Jan",
    2 => "Feb",
    3 => "Mar",
    4 => "Apr",
    5 => "May",
    6 => "Jun",
    7 => "Jul",
    8 => "Aug",
    9 => "Sep",
    10 => "Oct",
    11 => "Nov",
    12 => "Dec"
  }

  @day_names %{
    1 => "Mon",
    2 => "Tue",
    3 => "Wed",
    4 => "Thu",
    5 => "Fri",
    6 => "Sat",
    7 => "Sun"
  }

  @gmt_time_zone "GMT"

  @utc_time_zone "Etc/UTC"

  #######
  # API #
  #######

  defstruct date_time: nil

  def utc_formatted_string_now(%DateTime{} = date_time \\ DateTime.utc_now()) do
    date_time
    |> from_date_time()
    |> to_utc_string()
  end

  def from_date_time(%DateTime{} = date_time) do
    {:ok, utc_date_time} =
      DateTime.shift_zone(date_time, @utc_time_zone, UTCOnlyTimeZoneDatabase)

    struct!(__MODULE__, date_time: utc_date_time)
  end

  def to_utc_string(%__MODULE__{date_time: %DateTime{} = date_time}) do
    day_name(date_time) <>
      ", " <>
      padded_day(date_time) <>
      " " <>
      month_name(date_time) <>
      " " <>
      padded_year(date_time) <>
      " " <>
      padded_hour(date_time) <>
      ":" <>
      padded_minute(date_time) <>
      ":" <> padded_second(date_time) <> " " <> time_zone(date_time)
  end

  ###########
  # Private #
  ###########

  defp day_name(%DateTime{} = date_time) do
    date_time
    |> DateTime.to_date()
    |> Date.day_of_week()
    |> case do
      day ->
        Map.fetch!(@day_names, day)
    end
  end

  defp month_name(%DateTime{month: month}) do
    Map.fetch!(@month_names, month)
  end

  defp padded_day(%DateTime{day: day}) do
    day
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp padded_hour(%DateTime{hour: hour}) do
    hour
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp padded_minute(%DateTime{minute: minute}) do
    minute
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp padded_second(%DateTime{second: second}) do
    second
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp padded_year(%DateTime{year: year}) do
    year
    |> Integer.to_string()
    |> String.pad_leading(4, "0")
  end

  defp time_zone(%DateTime{time_zone: @utc_time_zone}) do
    @gmt_time_zone
  end
end
