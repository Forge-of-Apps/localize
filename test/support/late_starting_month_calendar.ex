defmodule Localize.Test.LateStartingMonthCalendar do
  @moduledoc false

  # The Gregorian calendar but for one year that begins part-way through a
  # month, as `Calendrical.Reform.England`'s 1751 began on 25 March: England
  # moved the year's start from 25 March to 1 January, so its 1751 ran from
  # 25 March to 31 December. That March holds the 25th to the 31st and no
  # 1st, and January and February of 1751 hold no day at all.
  #
  # The months and days are the ones a date is written with, unlike
  # `Localize.Test.CountedMonthCalendar`, which counts its months from the
  # year's first day and names them through `cardinal_month/1`. So a month of
  # this calendar can lack its 1st, which is what a year and a month with no
  # day used to be checked as. Localize does not depend on Calendrical, so
  # this stands in for one of its calendars.

  use Localize.Test.StandInCalendar

  @short_year 1751
  @year_starts_on {3, 25}
  @months_before_the_year_starts 1..2

  def months_in_year(_year), do: 12

  def days_in_month(@short_year, month) when month in @months_before_the_year_starts, do: 0

  def days_in_month(@short_year, 3) do
    {_month, first} = @year_starts_on
    Calendar.ISO.days_in_month(@short_year, 3) - first + 1
  end

  def days_in_month(year, month), do: Calendar.ISO.days_in_month(year, month)

  def valid_date?(@short_year, month, _day) when month in @months_before_the_year_starts,
    do: false

  def valid_date?(@short_year, 3, day) do
    {_month, first} = @year_starts_on

    day in first..Calendar.ISO.days_in_month(@short_year, 3)
  end

  def valid_date?(year, month, day), do: Calendar.ISO.valid_date?(year, month, day)

  # The days of a month, which `Localize.Calendar.validate_value/1` asks for
  # a year and a month naming no day. A month the year does not reach is no
  # month of it.
  def month(@short_year, month) when month in @months_before_the_year_starts,
    do: {:error, :invalid_date}

  def month(year, month) when month in 1..12 do
    with {:ok, first} <- first_day(year, month),
         {:ok, last} <-
           Date.new(year, month, days_in_month(year, month) + first.day - 1, __MODULE__) do
      Date.range(first, last)
    end
  end

  def month(_year, _month), do: {:error, :invalid_date}

  defp first_day(@short_year, 3) do
    {_month, first} = @year_starts_on

    Date.new(@short_year, 3, first, __MODULE__)
  end

  defp first_day(year, month), do: Date.new(year, month, 1, __MODULE__)
end
