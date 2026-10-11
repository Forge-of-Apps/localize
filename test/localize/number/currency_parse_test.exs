defmodule Localize.Number.CurrencyParseTest do
  @moduledoc """
  Covers reading a currency amount with the separators it was written with.

  `Localize.Number.to_string/2` writes a currency amount with the locale's
  currency separators, so reading it back needs the same ones. In `de-AT` the
  two sets disagree — `€ 1.234,56` for a currency amount against `1 234,56`
  plain — so `"1.234,56"` is a different number with and without the
  `:currency` option, and without it the plain reader refuses the string
  outright.

  """

  use ExUnit.Case, async: true

  alias Localize.Number
  alias Localize.Number.Parser

  describe "a currency amount written by to_string/2" do
    test "reads back to the number it was written from" do
      for {locale, currency} <- [{:"de-AT", :EUR}, {:"fr-CH", :CHF}, {:en, :USD}, {:de, :EUR}] do
        {:ok, formatted} =
          Number.to_string(Decimal.new("1234.56"), locale: locale, currency: currency)

        digits = String.replace(formatted, ~r/[^\d.,'\x{00A0}\x{202F} ]/u, "") |> String.trim()

        assert {:ok, 1234.56} = Parser.parse(digits, locale: locale, currency: currency),
               "#{locale}/#{currency} wrote #{inspect(formatted)} which did not read back"
      end
    end
  end

  describe "the :currency option" do
    test "reads de-AT's dot as a group separator" do
      assert {:ok, 1234.56} = Parser.parse("1.234,56", locale: :"de-AT", currency: :EUR)
    end

    test "is refused as a plain number, where the dot is not a group separator" do
      assert {:error, %Localize.InvalidValueError{}} = Parser.parse("1.234,56", locale: :"de-AT")
    end

    test "reads fr-CH's dot as a decimal separator" do
      assert {:ok, 1234.56} = Parser.parse("1'234.56", locale: :"fr-CH", currency: :CHF)
    end

    test "accepts a Currency struct as well as a code" do
      {:ok, currency} = Localize.Currency.currency_for_code(:EUR, locale: :"de-AT")
      assert {:ok, 1234.56} = Parser.parse("1.234,56", locale: :"de-AT", currency: currency)
    end

    test "changes nothing for a locale whose two sets agree" do
      assert Parser.parse("1,234.56", locale: :en, currency: :USD) ==
               Parser.parse("1,234.56", locale: :en)
    end
  end

  describe "the :separators option" do
    test "reads en-ZA with its us set" do
      assert {:ok, 1234.56} = Parser.parse("1,234.56", locale: :"en-ZA", separators: :us)
    end

    test "reads en-ZA with its standard set by default" do
      assert {:ok, 1234.56} = Parser.parse("1 234,56", locale: :"en-ZA")
    end

    test "falls back to the standard set for a locale without the named one" do
      assert Parser.parse("1,234.56", locale: :en, separators: :no_such_set) ==
               Parser.parse("1,234.56", locale: :en)
    end
  end
end
