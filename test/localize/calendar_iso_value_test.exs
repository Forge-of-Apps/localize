defmodule Localize.CalendarISOValueTest do
  @moduledoc """
  `Localize.Calendar.ISO` is a full calendar: it passes every callback of
  Elixir's `Calendar` behaviour to `Calendar.ISO` and implements the
  Calendrical behaviour's itself, so a value may name it as its calendar.
  A caller that needs one module answering both behaviours holds its dates
  in it (user, 2026-10-11: "build ... the Localize.Calendar.ISO module to
  be a full calendar implementations - delegating to Calendar.ISO for
  Calendar callbacks and implementing the Calendrical callbacks itself").

  A date of it is the `Calendar.ISO` date of the same year, month and day
  under another module's name. So the dates it answers with are its own,
  Elixir's `Date` functions take them as they take any calendar's, and
  Localize reads, writes and numbers the weeks of a value held in it
  exactly as it does the `Calendar.ISO` value: the tests below compare the
  two, format by format.

  """

  use ExUnit.Case, async: true

  alias Localize.Calendar.ISO

  @locales [:en, :"en-GB", :de, :fr, :he]

  @dates [
    ~D[2026-06-15],
    ~D[2024-02-29],
    ~D[2027-01-01],
    ~D[2021-10-01],
    ~D[0001-01-01],
    ~D[-0044-03-15]
  ]

  # Standard formats, skeletons and patterns, the fields of a week among
  # them: `Calendar.ISO`'s weeks are the locale's, and so are this module's.
  @date_formats [:short, :medium, :long, :full, :yMMM, :yMd, :yMMMEd, :yw, :MMMMW, :yQQQ] ++
                  ["Y-'W'ww-e", "y-MM-dd", "EEEE", "w", "W", "Y", "D", "F", "e", "G"]

  describe "the dates it answers with" do
    test "are dates of itself" do
      answers = [
        ISO.year(2026),
        ISO.semester(2026, 2),
        ISO.quadrimester(2026, 3),
        ISO.quarter(2026, 4),
        ISO.month(2024, 2),
        ISO.week(2026, 53),
        ISO.week(2027, 1, {7, 1}),
        ISO.month_week(2026, 6, 1)
      ]

      for %Date.Range{first: first, last: last} = days <- answers do
        assert first.calendar == ISO
        assert last.calendar == ISO
        assert Enum.all?(days, &(&1.calendar == ISO))
      end

      assert [%Date.Range{first: %Date{calendar: ISO}}] = ISO.named_month(2026, 6)
      assert %Date{calendar: ISO} = ISO.date_from_day_of_year(2026, 166)
      assert [%Date{calendar: ISO}] = ISO.dates_in_gregorian_year(2024, 2, 29)
    end

    test "are the Calendar.ISO dates of the same days" do
      assert Date.convert(ISO.date_from_day_of_year(2026, 166), Calendar.ISO) ==
               {:ok, ~D[2026-06-15]}

      assert Enum.map(ISO.week(2026, 53), &Date.convert!(&1, Calendar.ISO)) ==
               Enum.to_list(Date.range(~D[2026-12-28], ~D[2027-01-03]))

      for date <- @dates do
        assert {:ok, own} = Date.convert(date, ISO)
        assert own.calendar == ISO
        assert {own.year, own.month, own.day} == {date.year, date.month, date.day}
        assert Date.convert(own, Calendar.ISO) == {:ok, date}
      end
    end

    test "a date written for it is read as a date of it" do
      assert ISO.parsing_calendar() == ISO
      assert Localize.Calendar.parsing_calendar(ISO) == {:ok, ISO}
      assert Localize.Calendar.parsing_calendar(Calendar.ISO) == {:ok, Calendar.ISO}
    end
  end

  describe "as a calendar of Elixir's" do
    test "it declares the Calendar behaviour" do
      declared = ISO.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
      assert Calendar in declared
    end

    test "Date builds, steps, counts and lists its dates" do
      assert {:ok, date} = Date.new(2026, 6, 15, ISO)
      assert Date.new(2026, 2, 30, ISO) == {:error, :invalid_date}

      assert Date.add(date, 20) == Date.new!(2026, 7, 5, ISO)
      assert Date.shift(date, month: 1) == Date.new!(2026, 7, 15, ISO)
      assert Date.diff(date, Date.new!(2026, 1, 1, ISO)) == 165
      assert Date.diff(date, ~D[2026-01-01]) == 165
      assert Date.day_of_week(date) == 1
      assert Date.compare(date, ~D[2026-06-15]) == :eq
      assert Date.end_of_month(date) == Date.new!(2026, 6, 30, ISO)

      days = Date.range(date, Date.add(date, 6))
      assert Enum.count(days) == 7
      assert Enum.at(days, 6) == Date.new!(2026, 6, 21, ISO)
    end

    test "NaiveDateTime and DateTime hold it" do
      assert {:ok, naive} = NaiveDateTime.new(2026, 6, 15, 9, 30, 0, {0, 0}, ISO)
      assert NaiveDateTime.convert(naive, Calendar.ISO) == {:ok, ~N[2026-06-15 09:30:00]}
      assert NaiveDateTime.add(naive, 3600).hour == 10

      assert {:ok, zoned} = DateTime.from_naive(naive, "Etc/UTC")
      assert zoned.calendar == ISO
      assert DateTime.to_unix(zoned) == DateTime.to_unix(~U[2026-06-15 09:30:00Z])
    end
  end

  describe "a value held in it is formatted as the Calendar.ISO value is" do
    test "a date and a date with no day or no month" do
      values =
        @dates ++
          [
            %{year: 2026, month: 6, calendar: Calendar.ISO},
            %{year: 2026, calendar: Calendar.ISO},
            %{month: 6, day: 15, calendar: Calendar.ISO}
          ]

      different =
        for locale <- @locales,
            value <- values,
            format <- @date_formats,
            options = [format: format, locale: locale],
            written = answer(Localize.Date.to_string(value, options)),
            held = answer(Localize.Date.to_string(held_in_it(value), options)),
            written != held,
            do: {value, format, locale, written, held}

      assert different == []
    end

    test "a date and time" do
      {:ok, zoned} = DateTime.new(~D[2026-06-15], ~T[09:30:45], "Etc/UTC")

      different =
        for locale <- @locales,
            value <- [~N[2026-06-15 09:30:45], ~N[2027-01-01 00:00:00], zoned],
            format <- [:short, :medium, :long, :full, :yMMMdjm],
            options = [format: format, locale: locale],
            written = answer(Localize.DateTime.to_string(value, options)),
            held = answer(Localize.DateTime.to_string(held_in_it(value), options)),
            written != held,
            do: {value, format, locale, written, held}

      assert different == []
    end

    test "a time of day" do
      different =
        for locale <- @locales,
            value <- [~T[09:30:45], ~T[23:59:59]],
            format <- [:short, :medium, :hms, :Hm],
            options = [format: format, locale: locale],
            written = answer(Localize.Time.to_string(value, options)),
            held = answer(Localize.Time.to_string(held_in_it(value), options)),
            written != held,
            do: {value, format, locale, written, held}

      assert different == []
    end

    test "an interval" do
      intervals = [
        {~D[2026-06-15], ~D[2026-06-20]},
        {~D[2026-06-15], ~D[2027-01-02]},
        {~N[2026-06-15 09:00:00], ~N[2026-06-15 17:00:00]}
      ]

      different =
        for locale <- @locales,
            {from, to} <- intervals,
            format <- [:short, :medium, :long],
            options = [format: format, locale: locale],
            written = answer(Localize.Interval.to_string(from, to, options)),
            held =
              answer(Localize.Interval.to_string(held_in_it(from), held_in_it(to), options)),
            written != held,
            do: {from, to, format, locale, written, held}

      assert different == []
    end

    test "a date relative to another" do
      pairs = [
        {~D[2026-06-18], ~D[2026-06-15]},
        {~D[2026-07-20], ~D[2026-06-15]},
        {~N[2026-06-15 12:00:00], ~N[2026-06-15 09:00:00]}
      ]

      different =
        for locale <- @locales,
            {value, from} <- pairs,
            unit <- [nil, :day, :week, :month],
            options = unit_option(unit) ++ [locale: locale],
            written =
              answer(Localize.DateTime.Relative.to_string(value, [relative_to: from] ++ options)),
            held =
              answer(
                Localize.DateTime.Relative.to_string(
                  held_in_it(value),
                  [relative_to: held_in_it(from)] ++ options
                )
              ),
            written != held,
            do: {value, from, unit, locale, written, held}

      assert different == []
    end
  end

  describe "text is read into it as into Calendar.ISO" do
    test "in a locale's formats and in ISO 8601's" do
      for text <- ["June 15, 2026", "6/15/26", "2026-06-15", "2026-W25-1", "2026-166"] do
        assert {:ok, %Date{calendar: Calendar.ISO} = date} =
                 Localize.Date.parse(text, locale: :en)

        assert Localize.Date.parse(text, locale: :en, calendar: ISO) ==
                 {:ok, Date.new!(date.year, date.month, date.day, ISO)}
      end

      assert Localize.DateTime.parse("June 15, 2026, 9:30 AM", locale: :en, calendar: ISO) ==
               NaiveDateTime.new(2026, 6, 15, 9, 30, 0, {0, 0}, ISO)
    end

    test "and text that is no date is none in either" do
      for text <- ["2026-06", "2026-02-30", "June 31, 2026"] do
        assert {:error, %Localize.DateParseError{calendar: Calendar.ISO}} =
                 Localize.Date.parse(text, locale: :en)

        assert {:error, %Localize.DateParseError{calendar: ISO}} =
                 Localize.Date.parse(text, locale: :en, calendar: ISO)
      end
    end
  end

  # The same fields, held in `Localize.Calendar.ISO`.
  defp held_in_it(value), do: %{value | calendar: ISO}

  defp unit_option(nil), do: []
  defp unit_option(unit), do: [unit: unit]

  # What a format answers: its text, or the kind of error it is, which is
  # the same for both where a value has not the fields a format needs.
  defp answer({:ok, text}), do: {:ok, text}

  defp answer({:error, exception}) when is_exception(exception),
    do: {:error, exception.__struct__}
end
