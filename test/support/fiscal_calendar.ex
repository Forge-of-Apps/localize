defmodule Localize.Test.FiscalCalendar do
  @moduledoc false

  # A fiscal year that begins on 1 July and is numbered by the year it ends
  # in, as Calendrical's `Calendrical.FiscalYear.AU` is: year 2027 runs from
  # 1 July 2026 to 30 June 2027, its month 1 is July and its month 12 June.
  # Its months are named as the Gregorian months they are, so a date is
  # written as the Gregorian date it is: month 2 day 10 of 2027 is written
  # "August 10, 2026". `cardinal_year/3` gives the year a date is written
  # with and `date_from_cardinal_date/3` reads a written date back, which
  # the formatter and the parser ask of a calendar that exports them.
  # Localize does not depend on Calendrical, so this stands in for one of
  # its calendars.

  use Localize.Test.StandInCalendar

  @months_before_january 6

  def month_of_year(_year, month, _day), do: month

  def cardinal_month(month), do: Integer.mod(month + @months_before_january - 1, 12) + 1

  def calendar_year(year, _month, _day), do: year

  def cardinal_year(year, month, _day) when month <= @months_before_january, do: year - 1
  def cardinal_year(year, _month, _day), do: year

  def date_from_cardinal_date(year, month, day) do
    if Calendar.ISO.valid_date?(year, month, day),
      do: fiscal_date(year, month, day),
      else: {:error, :invalid_date}
  end

  def days_in_month(year, month) when month in 1..12,
    do: Calendar.ISO.days_in_month(cardinal_year(year, month, 1), cardinal_month(month))

  def days_in_month(_year, _month), do: 0

  def valid_date?(year, month, day)
      when is_integer(year) and month in 1..12 and is_integer(day) and day >= 1,
      do: day <= days_in_month(year, month)

  def valid_date?(_year, _month, _day), do: false

  def day_of_week(year, month, day, starting_on) do
    {gregorian_year, gregorian_month, gregorian_day} = gregorian_date(year, month, day)
    Calendar.ISO.day_of_week(gregorian_year, gregorian_month, gregorian_day, starting_on)
  end

  # Its months are the Gregorian months one for one, so a shift is the
  # Gregorian date's.
  def shift_date(year, month, day, duration) do
    {gregorian_year, gregorian_month, gregorian_day} = gregorian_date(year, month, day)

    {shifted_year, shifted_month, shifted_day} =
      Calendar.ISO.shift_date(gregorian_year, gregorian_month, gregorian_day, duration)

    fiscal_date(shifted_year, shifted_month, shifted_day)
  end

  def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
    {gregorian_year, gregorian_month, gregorian_day} = gregorian_date(year, month, day)

    Calendar.ISO.naive_datetime_to_iso_days(
      gregorian_year,
      gregorian_month,
      gregorian_day,
      hour,
      minute,
      second,
      microsecond
    )
  end

  def naive_datetime_from_iso_days(iso_days) do
    {year, month, day, hour, minute, second, microsecond} =
      Calendar.ISO.naive_datetime_from_iso_days(iso_days)

    {fiscal_year, fiscal_month, fiscal_day} = fiscal_date(year, month, day)
    {fiscal_year, fiscal_month, fiscal_day, hour, minute, second, microsecond}
  end

  defp gregorian_date(year, month, day),
    do: {cardinal_year(year, month, day), cardinal_month(month), day}

  defp fiscal_date(year, month, day) when month > @months_before_january,
    do: {year + 1, month - @months_before_january, day}

  defp fiscal_date(year, month, day), do: {year, month + @months_before_january, day}
end
