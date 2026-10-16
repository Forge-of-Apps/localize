defmodule Localize.FiscalCalendarTest do
  @moduledoc """
  Covers a fiscal calendar, whose dates are written as the Gregorian dates
  they are.

  `Localize.Test.FiscalCalendar` stands in for `Calendrical.FiscalYear.AU`,
  which Localize cannot load: its year 2027 runs from 1 July 2026, and its
  months are named as the Gregorian months they are. A date of it was
  written with its month's name and its fiscal year, so its month 2 day 10
  of 2027, 10 August 2026, was "Aug 10, 2027" (found from Tempo,
  2026-10-15). The formatter now writes the year through the calendar's
  `cardinal_year/3`, the parser reads the written date back through its
  `date_from_cardinal_date/3`, and an interval compares the years written.

  """

  use ExUnit.Case, async: true

  alias Localize.Test.FiscalCalendar, as: Fiscal

  # Each fiscal date beside the Gregorian date it is written as: July to
  # December fall in the Gregorian year before the fiscal year's number.
  @dates [
    {{2027, 1, 1}, "July 1, 2026", "7/1/26"},
    {{2027, 2, 10}, "August 10, 2026", "8/10/26"},
    {{2027, 6, 31}, "December 31, 2026", "12/31/26"},
    {{2027, 7, 1}, "January 1, 2027", "1/1/27"},
    {{2027, 12, 30}, "June 30, 2027", "6/30/27"}
  ]

  describe "a fiscal date" do
    test "is written as the Gregorian date it is" do
      for {{year, month, day}, long, short} <- @dates do
        date = Date.new!(year, month, day, Fiscal)

        assert Localize.Date.to_string(date, format: :long, locale: :en) == {:ok, long}
        assert Localize.Date.to_string(date, format: :short, locale: :en) == {:ok, short}
      end
    end

    test "is read back from the Gregorian date it is written as" do
      for {{year, month, day}, long, short} <- @dates,
          {text, format} <- [{long, :long}, {short, :short}] do
        assert Localize.Date.parse(text, calendar: Fiscal, format: format, locale: :en) ==
                 {:ok, Date.new!(year, month, day, Fiscal)},
               text
      end
    end

    test "is read back on every day of two years" do
      for iso <- Date.range(~D[2026-01-01], ~D[2027-12-31]), format <- [:long, :medium, :short] do
        date = Date.convert!(iso, Fiscal)
        {:ok, text} = Localize.Date.to_string(date, format: format, locale: :en)

        assert Localize.Date.parse(text, calendar: Fiscal, format: format, locale: :en) ==
                 {:ok, date},
               text
      end
    end
  end

  describe "an interval of fiscal dates" do
    # 10 August 2026 to 15 February 2027 are both of fiscal year 2027, and
    # are written with two years.
    test "writes both years where its dates are written with two" do
      assert {:ok, text} =
               Localize.Interval.to_string(
                 Date.new!(2027, 2, 10, Fiscal),
                 Date.new!(2027, 8, 15, Fiscal),
                 format: :medium,
                 locale: :en
               )

      assert text =~ "Aug 10, 2026"
      assert text =~ "Feb 15, 2027"
    end

    test "writes one year where its dates are written with one" do
      assert {:ok, text} =
               Localize.Interval.to_string(
                 Date.new!(2027, 2, 10, Fiscal),
                 Date.new!(2027, 2, 20, Fiscal),
                 format: :medium,
                 locale: :en
               )

      refute text =~ "2027"
      assert text =~ "2026"
    end

    test "has its year as its greatest difference across 1 January" do
      assert Localize.Interval.greatest_difference(
               Date.new!(2027, 6, 31, Fiscal),
               Date.new!(2027, 7, 1, Fiscal)
             ) == {:ok, :y}
    end
  end
end
