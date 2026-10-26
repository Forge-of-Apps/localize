defmodule Localize.Number.FormatTypeSignMatrixTest do
  # Every format type, for an integer, a float and a Decimal, at zero,
  # positive and negative, whole and fractional. A value must format the
  # same whatever its type: #62 was a Decimal zero that raised where the
  # integer and the float zero formatted.
  use ExUnit.Case, async: true

  @currency [currency: :USD]

  # {format, extra options, results for 0, 1234, -1234, 1234.5, -1234.5},
  # the same for an integer, a Decimal and, for the fractional values, a
  # float; a whole float matches the integer outside RBNF (below).
  @expected [
    {:standard, [], ["0", "1,234", "-1,234", "1,234.5", "-1,234.5"]},
    {:percent, [], ["0%", "123,400%", "-123,400%", "123,450%", "-123,450%"]},
    {:scientific, [], ["0E0", "1.234E3", "-1.234E3", "1.2345E3", "-1.2345E3"]},
    {:engineering, [], ["0E0", "1.234E3", "-1.234E3", "1.2345E3", "-1.2345E3"]},
    {:decimal_short, [], ["0", "1.2K", "-1.2K", "1.2K", "-1.2K"]},
    {:decimal_long, [], ["0", "1.2 thousand", "-1.2 thousand", "1.2 thousand", "-1.2 thousand"]},
    {:short, [], ["0", "1.2K", "-1.2K", "1.2K", "-1.2K"]},
    {:long, [], ["0", "1.2 thousand", "-1.2 thousand", "1.2 thousand", "-1.2 thousand"]},
    {:currency, @currency, ["$0.00", "$1,234.00", "-$1,234.00", "$1,234.50", "-$1,234.50"]},
    {:accounting, @currency, ["$0.00", "$1,234.00", "($1,234.00)", "$1,234.50", "($1,234.50)"]},
    {:currency_no_symbol, @currency, ["0.00", "1,234.00", "-1,234.00", "1,234.50", "-1,234.50"]},
    {:accounting_no_symbol, @currency,
     ["0.00", "1,234.00", "(1,234.00)", "1,234.50", "(1,234.50)"]},
    {:currency_alpha_next_to_number, @currency,
     ["$ 0.00", "$ 1,234.00", "-$ 1,234.00", "$ 1,234.50", "-$ 1,234.50"]},
    {:accounting_alpha_next_to_number, @currency,
     ["$ 0.00", "$ 1,234.00", "($ 1,234.00)", "$ 1,234.50", "($ 1,234.50)"]},
    {:currency_short, @currency, ["$0", "$1.2K", "-$1.2K", "$1.2K", "-$1.2K"]},
    {:currency_long, @currency,
     [
       "0.00 US dollars",
       "1,234.00 US dollars",
       "-1,234.00 US dollars",
       "1,234.50 US dollars",
       "-1,234.50 US dollars"
     ]},
    {:spellout, [],
     [
       "zero",
       "one thousand two hundred thirty-four",
       "minus one thousand two hundred thirty-four",
       "one thousand two hundred thirty-four point five",
       "minus one thousand two hundred thirty-four point five"
     ]},
    {:spellout_cardinal, [],
     [
       "zero",
       "one thousand two hundred thirty-four",
       "minus one thousand two hundred thirty-four",
       "one thousand two hundred thirty-four point five",
       "minus one thousand two hundred thirty-four point five"
     ]},
    {:spellout_cardinal_verbose, [],
     [
       "zero",
       "one thousand two hundred and thirty-four",
       "minus one thousand two hundred and thirty-four",
       "one thousand two hundred and thirty-four point five",
       "minus one thousand two hundred and thirty-four point five"
     ]},
    {:spellout_numbering, [],
     [
       "zero",
       "one thousand two hundred thirty-four",
       "minus one thousand two hundred thirty-four",
       "one thousand two hundred thirty-four point five",
       "minus one thousand two hundred thirty-four point five"
     ]},
    # CLDR's `x.x: =0.#=` rule formats a fraction without grouping.
    {:spellout_ordinal, [],
     [
       "zeroth",
       "one thousand two hundred thirty-fourth",
       "minus one thousand two hundred thirty-fourth",
       "1234.5",
       "minus 1234.5"
     ]},
    {:spellout_numbering_year, [],
     ["zero", "twelve thirty-four", "minus twelve thirty-four", "1234.5", "minus 1234.5"]},
    # en's digits-ordinal has no fraction rule.
    {:ordinal, [], ["0th", "1,234th", "−1,234th", "1,234th", "−1,234th"]},
    {:digits_ordinal, [], ["0th", "1,234th", "−1,234th", "1,234th", "−1,234th"]},
    # root's roman-upper has `x.x: =#,##0.00=`.
    {:roman_upper, [], ["N", "MCCXXXIV", "−MCCXXXIV", "1,234.50", "−1,234.50"]},
    {"#,##0.00", [], ["0.00", "1,234.00", "-1,234.00", "1,234.50", "-1,234.50"]}
  ]

  # An RBNF rule set applies its fraction rule to any float, a whole one
  # included, where an integer or a whole Decimal takes the integer rules.
  # Results for 0.0, 1234.0 and -1234.0.
  @rbnf_whole_floats [
    {:spellout,
     [
       "zero point zero",
       "one thousand two hundred thirty-four point zero",
       "minus one thousand two hundred thirty-four point zero"
     ]},
    {:spellout_ordinal, ["0", "1234", "minus 1234"]},
    {:spellout_numbering_year, ["0", "1234", "minus 1234"]},
    {:roman_upper, ["0.00", "1,234.00", "−1,234.00"]},
    {:ordinal, ["0th", "1,234th", "−1,234th"]}
  ]

  @rbnf_formats [
    :spellout,
    :spellout_cardinal,
    :spellout_cardinal_verbose,
    :spellout_numbering,
    :spellout_ordinal,
    :spellout_numbering_year,
    :ordinal,
    :digits_ordinal,
    :roman_upper
  ]

  defp format(value, format, extra, locale \\ :en) do
    Localize.Number.to_string(value, [locale: locale, format: format] ++ extra)
  end

  describe "en, every format" do
    for {format, extra, [zero, positive, negative, positive_fraction, negative_fraction]} <-
          @expected do
      @format format
      @extra extra

      test "#{inspect(format)} formats an integer, a Decimal and a float alike" do
        for {value, expected} <- [
              {0, unquote(zero)},
              {1234, unquote(positive)},
              {-1234, unquote(negative)}
            ] do
          assert format(value, @format, @extra) == {:ok, expected}
          assert format(Decimal.new(value), @format, @extra) == {:ok, expected}

          if @format not in @rbnf_formats do
            assert format(value * 1.0, @format, @extra) == {:ok, expected}
          end
        end

        for {value, expected} <- [
              {"1234.5", unquote(positive_fraction)},
              {"-1234.5", unquote(negative_fraction)}
            ] do
          assert format(Decimal.new(value), @format, @extra) == {:ok, expected}
          assert format(String.to_float(value), @format, @extra) == {:ok, expected}
        end
      end

      test "#{inspect(format)} formats every form of a Decimal zero as zero" do
        for zero <- [Decimal.new("0.00"), Decimal.new("0E+5")] do
          assert format(zero, @format, @extra) == {:ok, unquote(zero)}
        end
      end
    end
  end

  describe "en, a whole float in an RBNF format" do
    for {format, [zero, positive, negative]} <- @rbnf_whole_floats do
      test "#{inspect(format)} applies the fraction rule" do
        assert format(0.0, unquote(format), []) == {:ok, unquote(zero)}
        assert format(1234.0, unquote(format), []) == {:ok, unquote(positive)}
        assert format(-1234.0, unquote(format), []) == {:ok, unquote(negative)}
      end
    end
  end

  describe "other locales" do
    for locale <- [:de, :ar] do
      test "#{locale}: every format gives one result per value, whatever its type" do
        for {format, extra, _expected} <- @expected,
            {whole, fraction} <- [{0, "0.5"}, {1234, "1234.5"}, {-1234, "-1234.5"}] do
          integer = format(whole, format, extra, unquote(locale))

          case integer do
            {:ok, _string} ->
              assert format(Decimal.new(whole), format, extra, unquote(locale)) == integer

              if format not in @rbnf_formats do
                assert format(whole * 1.0, format, extra, unquote(locale)) == integer
              end

              assert format(Decimal.new(fraction), format, extra, unquote(locale)) ==
                       format(String.to_float(fraction), format, extra, unquote(locale))

            # A rule set the locale does not have is an error for every type.
            {:error, %Localize.UnknownRbnfRuleError{}} ->
              assert {:error, %Localize.UnknownRbnfRuleError{}} =
                       format(Decimal.new(whole), format, extra, unquote(locale))
          end
        end
      end
    end
  end
end
