defmodule Localize.Test.StandInCalendar do
  @moduledoc false

  # Every question Localize puts to a calendar other than `Calendar.ISO`
  # (the callbacks `Localize.Calendar.validate_calendar/1` checks), answered
  # as the Gregorian calendar answers it: the Calendrical behaviour's that
  # Localize asks, and every `Calendar` callback, passed to `Calendar.ISO`.
  # Localize does not depend on Calendrical, so a test calendar stands in
  # for one of Calendrical's: it uses this module and overrides the answers
  # it is about. `without: [date_from_week_date: 3]` leaves answers out, for
  # a calendar that cannot give them.
  #
  # A year's days (`year/1`) and the arithmetic of months and years (`plus/6`
  # and `diff/3`) are answered from the calendar's own `Calendar` callbacks,
  # its `months_in_year/1`, `days_in_month/2` and `shift_date/4`, as
  # Calendrical derives a calendar's from them, so a stand-in that overrides
  # those answers the rest to match.

  @localize_answers [
    cldr_calendar_type: 0,
    era_calendar_type: 0,
    parsing_calendar: 0,
    date_from_week_date: 3,
    month_of_year: 3,
    cardinal_month: 1,
    extended_year: 3,
    related_gregorian_year: 3,
    cyclic_year: 3,
    week_of_year: 3,
    week_of_month: 3,
    week: 2,
    quarter: 2,
    year: 1,
    shift: 6,
    diff: 3,
    cldr_calendar_type: 3,
    parsing_calendars: 0,
    info: 0,
    leap_month: 1,
    cldr_month: 2,
    written_month_from_cldr_month: 2,
    written_date: 3,
    date_from_written_date: 3
  ]

  @calendar_callbacks Calendar.behaviour_info(:callbacks) --
                        Calendar.behaviour_info(:optional_callbacks)

  defmacro __using__(options) do
    without = Keyword.get(options, :without, [])
    answers = Enum.reject(@localize_answers ++ @calendar_callbacks, &(&1 in without))
    definitions = Enum.map(answers, &definition/1)

    quote do
      unquote_splicing(definitions)
      defoverridable unquote(answers)
    end
  end

  @doc false
  # A stand-in's answer to a question it may not have, or `default`.
  def answer(calendar, function, arguments, default \\ nil) do
    if function_exported?(calendar, function, length(arguments)),
      do: apply(calendar, function, arguments),
      else: default
  end

  @doc false
  # The module that names the calendars of a stand-in's family: the stand-in
  # itself where it answers `calendar_from_cldr_calendar_type/1`, as a
  # Calendrical calendar's `info/0` names `Calendrical`.
  def family(calendar) do
    if function_exported?(calendar, :calendar_from_cldr_calendar_type, 1), do: calendar
  end

  @doc false
  def written_year(calendar, year, month, day) do
    if function_exported?(calendar, :cardinal_year, 3),
      do: calendar.cardinal_year(year, month, day),
      else: answer(calendar, :calendar_year, [year, month, day], year)
  end

  @doc false
  # The CLDR month of a stand-in's month. Matched here at runtime rather
  # than in the code each stand-in is given, where the type checker sees a
  # stand-in's narrower `month_of_year/3` and warns that the other clauses
  # never match.
  def cldr_month(calendar, year, month) do
    case calendar.month_of_year(year, month, 1) do
      {named, :leap} when is_integer(named) -> {calendar.cardinal_month(named), :leap}
      named when is_integer(named) -> calendar.cardinal_month(named)
      other -> other
    end
  end

  @doc false
  def date_from_written_date(calendar, year, month, day) do
    if function_exported?(calendar, :date_from_cardinal_date, 3) do
      case calendar.date_from_cardinal_date(year, month, day) do
        {date_year, date_month, date_day} -> {:ok, {date_year, date_month, date_day}}
        _no_date -> {:error, :invalid_date}
      end
    else
      date_of_cldr_month(calendar, year, month, day)
    end
  end

  # A month the CLDR month names, or the leap month of that name where the
  # year has no other, as the parser read a numbered month before the kernel.
  defp date_of_cldr_month(calendar, year, cldr_month, day) do
    if calendar.valid_date?(year, 1, 1) do
      months = 1..calendar.months_in_year(year)//1
      names = Map.new(months, &{calendar.cldr_month(year, &1), &1})

      case Map.get(names, cldr_month) || Map.get(names, {cldr_month, :leap}) do
        nil -> {:error, :invalid_date}
        month -> own_date(calendar, year, month, day)
      end
    else
      {:error, :invalid_date}
    end
  end

  defp own_date(calendar, year, month, day) do
    if calendar.valid_date?(year, month, day),
      do: {:ok, {year, month, day}},
      else: {:error, :invalid_date}
  end

  defp definition({:cldr_calendar_type, 0}),
    do: quote(do: def(cldr_calendar_type, do: :gregorian))

  defp definition({:era_calendar_type, 0}),
    do: quote(do: def(era_calendar_type, do: cldr_calendar_type()))

  defp definition({:parsing_calendar, 0}), do: quote(do: def(parsing_calendar, do: __MODULE__))

  defp definition({:cldr_calendar_type, 3}),
    do: quote(do: def(cldr_calendar_type(_year, _month, _day), do: cldr_calendar_type()))

  defp definition({:parsing_calendars, 0}),
    do: quote(do: def(parsing_calendars, do: [__MODULE__]))

  # The facts about the calendar, with the keys of Calendrical's
  # `Calendrical.Info`, read from the answers the stand-in gives so that a
  # calendar's own overrides are reflected.
  defp definition({:info, 0}) do
    quote do
      def info do
        %{
          calendar: __MODULE__,
          cldr_calendar_type: cldr_calendar_type(),
          era_calendar_type: era_calendar_type(),
          epoch: nil,
          year_zero?: true,
          structure: :months,
          months_in_year: {12, 12},
          weeks: %{first_day: 1, min_days_in_first_week: 4},
          years_in_cycle: nil,
          year_cycle: nil,
          location: nil,
          month_lengths: nil,
          parsing_calendar:
            Localize.Test.StandInCalendar.answer(__MODULE__, :parsing_calendar, []),
          family: Localize.Test.StandInCalendar.family(__MODULE__),
          members: nil
        }
      end
    end
  end

  defp definition({:leap_month, 1}), do: quote(do: def(leap_month(_year), do: nil))

  # The CLDR month of a month of a year: `month_of_year/3` named through
  # `cardinal_month/1`, as Calendrical derives it.
  defp definition({:cldr_month, 2}) do
    quote do
      def cldr_month(year, month) do
        Localize.Test.StandInCalendar.cldr_month(__MODULE__, year, month)
      end
    end
  end

  # A stand-in writes a month by its CLDR month, as Localize read every
  # calendar before the kernel, so the written month is the CLDR month.
  defp definition({:written_month_from_cldr_month, 2}),
    do: quote(do: def(written_month_from_cldr_month(_year, cldr_month), do: cldr_month))

  # The written date as Localize read a stand-in before the kernel: the year
  # its `cardinal_year/3` gives, or its `calendar_year/3`; the CLDR month;
  # and the day its `cardinal_day/3` gives, or the day.
  defp definition({:written_date, 3}) do
    quote do
      def written_date(year, month, day) do
        {Localize.Test.StandInCalendar.written_year(__MODULE__, year, month, day),
         cldr_month(year, month),
         Localize.Test.StandInCalendar.answer(__MODULE__, :cardinal_day, [year, month, day], day)}
      end
    end
  end

  # The date written figures name: the stand-in's `date_from_cardinal_date/3`
  # where it has one, else the year and the day with the month the CLDR
  # month is.
  defp definition({:date_from_written_date, 3}) do
    quote do
      def date_from_written_date(year, month, day),
        do: Localize.Test.StandInCalendar.date_from_written_date(__MODULE__, year, month, day)
    end
  end

  # ISO 8601's week date, as a date of the calendar using this module.
  defp definition({:date_from_week_date, 3}) do
    quote do
      def date_from_week_date(year, week, day) do
        case Localize.Calendar.ISO.date_from_week_date(year, week, day) do
          %Date{} = date -> Date.convert!(date, __MODULE__)
          error -> error
        end
      end
    end
  end

  defp definition({:month_of_year, 3}),
    do: quote(do: def(month_of_year(_year, month, _day), do: month))

  defp definition({:cardinal_month, 1}), do: quote(do: def(cardinal_month(month), do: month))

  defp definition({:calendar_year, 3}),
    do: quote(do: def(calendar_year(year, _month, _day), do: year))

  defp definition({:extended_year, 3}),
    do: quote(do: def(extended_year(year, _month, _day), do: year))

  defp definition({:related_gregorian_year, 3}),
    do: quote(do: def(related_gregorian_year(year, _month, _day), do: year))

  defp definition({:cyclic_year, 3}),
    do: quote(do: def(cyclic_year(year, _month, _day), do: year))

  defp definition({:week_of_year, 3}) do
    quote do
      def week_of_year(year, month, day), do: :calendar.iso_week_number({year, month, day})
    end
  end

  defp definition({:week_of_month, 3}) do
    quote do
      def week_of_month(year, month, day),
        do: Localize.Calendar.ISO.week_of_month(year, month, day)
    end
  end

  # ISO 8601's week `week` of `year`, in the calendar using this module.
  defp definition({:week, 2}) do
    quote do
      def week(year, week) do
        case Localize.Calendar.ISO.week(year, week) do
          %Date.Range{first: first, last: last} ->
            Date.range(Date.convert!(first, __MODULE__), Date.convert!(last, __MODULE__))

          error ->
            error
        end
      end
    end
  end

  # The Gregorian quarter `quarter` of `year`, in the calendar using this
  # module.
  defp definition({:quarter, 2}) do
    quote do
      def quarter(year, quarter) do
        case Localize.Calendar.ISO.quarter(year, quarter) do
          %Date.Range{first: first, last: last} ->
            Date.range(Date.convert!(first, __MODULE__), Date.convert!(last, __MODULE__))

          error ->
            error
        end
      end
    end
  end

  # The days of a year, from the first day of its first month to the last
  # day of its last, as the calendar using this module counts them.
  defp definition({:year, 1}) do
    quote do
      def year(year) do
        last_month = months_in_year(year)
        last_day = days_in_month(year, last_month)

        Date.range(
          %Date{year: year, month: 1, day: 1, calendar: __MODULE__},
          %Date{year: year, month: last_month, day: last_day, calendar: __MODULE__}
        )
      end
    end
  end

  # The date a number of years, quarters, months, weeks or days on, as the
  # calendar using this module shifts a date (its `shift_date/4`), which
  # brings the day into a shorter month.
  defp definition({:shift, 6}) do
    quote do
      def shift(year, month, day, date_part, increment, _options) do
        duration =
          case date_part do
            :years -> Duration.new!(year: increment)
            :quarters -> Duration.new!(month: increment * 3)
            :months -> Duration.new!(month: increment)
            :weeks -> Duration.new!(week: increment)
            :days -> Duration.new!(day: increment)
          end

        shift_date(year, month, day, duration)
      end
    end
  end

  defp definition({:diff, 3}) do
    quote do
      def diff(from, to, date_part),
        do: Localize.Test.StandInCalendar.diff(__MODULE__, from, to, date_part)
    end
  end

  defp definition({name, arity}) do
    arguments = Macro.generate_arguments(arity, __MODULE__)

    quote do
      def unquote(name)(unquote_splicing(arguments)),
        do: Calendar.ISO.unquote(name)(unquote_splicing(arguments))
    end
  end

  # The whole years, quarters, months, weeks or days from one date of a
  # calendar to another, the inverse of its `plus/6`: the most that adds to
  # the earlier date without passing the later, and negative when `to` is the
  # earlier.
  def diff(calendar, from, to, date_part) do
    if days(calendar, to) < days(calendar, from),
      do: -count(calendar, to, from, date_part),
      else: count(calendar, from, to, date_part)
  end

  defp count(calendar, from, to, :days), do: days(calendar, to) - days(calendar, from)
  defp count(calendar, from, to, :weeks), do: div(count(calendar, from, to, :days), 7)
  defp count(calendar, from, to, :quarters), do: div(count(calendar, from, to, :months), 3)

  defp count(calendar, {year, month, day}, to, date_part) do
    limit = days(calendar, to)

    past =
      Enum.find(Stream.iterate(1, &(&1 + 1)), fn count ->
        days(calendar, calendar.shift(year, month, day, date_part, count, clamp: true)) > limit
      end)

    past - 1
  end

  defp days(calendar, {year, month, day}) do
    {days, _fraction} = calendar.naive_datetime_to_iso_days(year, month, day, 0, 0, 0, {0, 0})
    days
  end
end
