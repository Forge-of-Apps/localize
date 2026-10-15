defmodule Localize.LateStartingMonthTest do
  @moduledoc """
  A year and a month naming no day, in a calendar whose year begins part-way
  through a month.

  `Localize.Test.LateStartingMonthCalendar` stands in for
  `Calendrical.Reform.England`, whose 1751 ran from 25 March to 31 December:
  England moved the year's start from 25 March to 1 January, so that March
  holds the 25th to the 31st and no 1st, and January and February of 1751
  hold no day at all.

  A year and a month were checked as the month's first day, so "Mar 1751" was
  refused as a value its calendar does not have. Found from Tempo.
  """

  use ExUnit.Case, async: true

  alias Localize.Test.LateStartingMonthCalendar, as: Calendar

  describe "a month that begins after its first day" do
    test "writes from its year and month" do
      assert {:ok, "Mar 1751"} =
               Localize.Date.to_string(%{year: 1751, month: 3, calendar: Calendar},
                 format: :yMMM
               )
    end

    test "writes at every format that wants no day of it" do
      value = %{year: 1751, month: 3, calendar: Calendar}

      assert {:ok, "March 1751"} = Localize.Date.to_string(value, format: :yMMMM)
      assert {:ok, "3/1751"} = Localize.Date.to_string(value, format: :yM)
    end

    test "a month whose days the year does not reach is still refused" do
      # The 1751 that began in March has no February, so there is no month to
      # write — unlike March, which has days the year does reach.
      assert {:error, %Localize.InvalidValueError{} = error} =
               Localize.Date.to_string(%{year: 1751, month: 2, calendar: Calendar},
                 format: :yMMM
               )

      assert error.value == %{year: 1751, month: 2}
      assert error.expected == "a date its calendar has"
    end

    test "a month out of the year's range is refused" do
      assert {:error, %Localize.InvalidValueError{}} =
               Localize.Date.to_string(%{year: 1751, month: 13, calendar: Calendar},
                 format: :yMMM
               )
    end
  end

  describe "the months either side" do
    test "a month opening on its 1st writes as it did" do
      assert {:ok, "Apr 1751"} =
               Localize.Date.to_string(%{year: 1751, month: 4, calendar: Calendar},
                 format: :yMMM
               )
    end

    test "the same month of a year the calendar reaches whole writes too" do
      assert {:ok, "Mar 1752"} =
               Localize.Date.to_string(%{year: 1752, month: 3, calendar: Calendar},
                 format: :yMMM
               )
    end

    test "a whole date of the short March is unaffected" do
      date = Date.new!(1751, 3, 25, Calendar)

      assert {:ok, "Mar 25, 1751"} = Localize.Date.to_string(date)
    end

    test "a day the short March does not hold is no date" do
      assert {:error, :invalid_date} = Date.new(1751, 3, 1, Calendar)
    end
  end
end
