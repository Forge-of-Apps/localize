defmodule Localize.Test.WeekMonthsCalendar do
  @moduledoc false

  # A calendar of weeks as Calendrical builds one, for tests: a date is a
  # year, a month of a 4-4-5 pattern of weeks and a day of that month, so a
  # month has 28 days or 35, and the twelfth 42 in a year of 53 weeks. Its
  # months are CLDR's generic calendar's ("M06") and its eras the Gregorian
  # calendar's; its weeks and quarters are its own; and text none of its
  # formats reads is read as a Gregorian date and converted, since it names
  # `Calendar.ISO` for parsing. Localize cannot load Calendrical's
  # calendars, so this stands in for them.
  #
  # The calendar using this module says where its years begin: `week_one/1`
  # is the ISO day count of the first day of a year's week 1
  # (`week_holding/4` counts one). It may count its own `weeks_in_year/1`.

  # The weeks of a quarter before each of its three months.
  @weeks_before_month {0, 4, 8}
  @weeks_in_quarter 13
  @days_in_week 7

  defmacro __using__(_options) do
    quote do
      use Localize.Test.StandInCalendar

      def cldr_calendar_type do
        :generic
      end

      def era_calendar_type do
        :gregorian
      end

      def parsing_calendar do
        Calendar.ISO
      end

      def weeks_in_year(year) do
        div(week_one(year + 1) - week_one(year), 7)
      end

      defoverridable weeks_in_year: 1

      def months_in_year(_year) do
        12
      end

      def days_in_month(year, month) do
        Localize.Test.WeekMonthsCalendar.weeks_in_month(__MODULE__, year, month) * 7
      end

      def valid_date?(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        month in 1..12 and day in 1..days_in_month(year, month)
      end

      def valid_date?(_year, _month, _day) do
        false
      end

      def month_of_year(_year, month, _day) do
        month
      end

      def year_of_era(year, _month, _day) do
        {year, 1}
      end

      def calendar_year(year, _month, _day) do
        year
      end

      def week_of_year(year, month, day) do
        {year, Localize.Test.WeekMonthsCalendar.first_week(month) + div(day - 1, 7)}
      end

      def week_of_month(_year, month, day) do
        {month, div(day - 1, 7) + 1}
      end

      def quarter_of_year(_year, month, _day) do
        div(month - 1, 3) + 1
      end

      def date_from_week_date(year, week, day) do
        Localize.Test.WeekMonthsCalendar.date_from_week_date(__MODULE__, year, week, day)
      end

      def week(year, week) do
        Localize.Test.WeekMonthsCalendar.week(__MODULE__, year, week)
      end

      def quarter(year, quarter) do
        Localize.Test.WeekMonthsCalendar.quarter(__MODULE__, year, quarter)
      end

      def day_of_week(year, month, day, starting_on) do
        days = Localize.Test.WeekMonthsCalendar.iso_days(__MODULE__, year, month, day)
        {iso_year, iso_month, iso_day} = Calendar.ISO.date_from_iso_days(days)
        Calendar.ISO.day_of_week(iso_year, iso_month, iso_day, starting_on)
      end

      def day_of_year(year, month, day) do
        Localize.Test.WeekMonthsCalendar.iso_days(__MODULE__, year, month, day) -
          week_one(year) + 1
      end

      def date_to_string(year, month, day) do
        Localize.Test.WeekMonthsCalendar.written(year, month, day)
      end

      def naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond) do
        {Localize.Test.WeekMonthsCalendar.iso_days(__MODULE__, year, month, day),
         Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)}
      end

      def naive_datetime_from_iso_days({days, fraction}) do
        {year, month, day} = Localize.Test.WeekMonthsCalendar.date_from_iso_days(__MODULE__, days)
        {hour, minute, second, microsecond} = Calendar.ISO.time_from_day_fraction(fraction)
        {year, month, day, hour, minute, second, microsecond}
      end

      def shift_date(year, month, day, duration) do
        Localize.Test.WeekMonthsCalendar.shift_date(__MODULE__, {year, month, day}, duration)
      end
    end
  end

  # The ISO day count of the first day of the week holding a Gregorian
  # date, where weeks begin on `starting_on`.
  def week_holding(year, month, day, starting_on) do
    {days, _fraction} = Calendar.ISO.naive_datetime_to_iso_days(year, month, day, 0, 0, 0, {0, 0})
    {weekday, _first, _last} = Calendar.ISO.day_of_week(year, month, day, starting_on)
    days - (weekday - 1)
  end

  # The week of the year a month begins with.
  def first_week(month) do
    div(month - 1, 3) * @weeks_in_quarter + elem(@weeks_before_month, rem(month - 1, 3)) + 1
  end

  # The twelfth month takes the weeks left in its year, a 53rd among them.
  def weeks_in_month(calendar, year, 12) do
    calendar.weeks_in_year(year) - first_week(12) + 1
  end

  def weeks_in_month(_calendar, _year, month) do
    first_week(month + 1) - first_week(month)
  end

  def month_of_week(week) do
    Enum.find(12..1//-1, &(first_week(&1) <= week))
  end

  def iso_days(calendar, year, month, day) do
    calendar.week_one(year) + (first_week(month) - 1) * @days_in_week + day - 1
  end

  def date_from_iso_days(calendar, days) do
    {gregorian_year, _month, _day} = Calendar.ISO.date_from_iso_days(days)
    years = [gregorian_year + 1, gregorian_year, gregorian_year - 1]
    year = Enum.find(years, &(calendar.week_one(&1) <= days))
    month = month_of_week(div(days - calendar.week_one(year), @days_in_week) + 1)

    {year, month, days - iso_days(calendar, year, month, 1) + 1}
  end

  # The date of a day of a week of a year, or an error for a week or a day
  # the year does not have.
  def date_from_week_date(calendar, year, week, day)
      when is_integer(week) and week >= 1 and day in 1..7 do
    if week <= calendar.weeks_in_year(year) do
      month = month_of_week(week)
      day_of_month = (week - first_week(month)) * @days_in_week + day

      %Date{year: year, month: month, day: day_of_month, calendar: calendar}
    else
      {:error, :invalid_date}
    end
  end

  def date_from_week_date(_calendar, _year, _week, _day) do
    {:error, :invalid_date}
  end

  def week(calendar, year, week) do
    first = date_from_week_date(calendar, year, week, 1)
    last = date_from_week_date(calendar, year, week, @days_in_week)

    days_between(first, last)
  end

  def quarter(calendar, year, quarter) when quarter in 1..4 do
    last_month = quarter * 3

    Date.range(
      %Date{year: year, month: last_month - 2, day: 1, calendar: calendar},
      %Date{
        year: year,
        month: last_month,
        day: calendar.days_in_month(year, last_month),
        calendar: calendar
      }
    )
  end

  def quarter(_calendar, _year, _quarter) do
    {:error, :invalid_date}
  end

  # Years and months move the month, twelve to a year, and the day is
  # brought into the month reached; weeks and days are then counted on.
  def shift_date(calendar, {year, month, day}, %Duration{} = duration) do
    months_on = (year + duration.year) * 12 + month - 1 + duration.month
    year_on = Integer.floor_div(months_on, 12)
    month_on = Integer.mod(months_on, 12) + 1
    day_on = min(day, calendar.days_in_month(year_on, month_on))
    days = iso_days(calendar, year_on, month_on, day_on)

    date_from_iso_days(calendar, days + duration.week * @days_in_week + duration.day)
  end

  def written(year, month, day) do
    "#{pad(year, 4)}-#{pad(month, 2)}-#{pad(day, 2)}"
  end

  defp days_between(%Date{} = first, %Date{} = last) do
    Date.range(first, last)
  end

  defp days_between(_no_first_day, _no_last_day) do
    {:error, :invalid_date}
  end

  defp pad(value, digits) do
    value
    |> Integer.to_string()
    |> String.pad_leading(digits, "0")
  end
end
