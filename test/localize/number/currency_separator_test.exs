defmodule Localize.Number.CurrencySeparatorTest do
  @moduledoc """
  Covers the separators a currency amount is written and read with.

  CLDR gives a locale a `currencyDecimal` or a `currencyGroup` symbol when it
  separates a currency amount differently from a plain number. In CLDR 49 two
  locales do: `fr-CH` has a `currencyDecimal` of `"."` where its plain decimal
  is `","`, and `de-AT` a `currencyGroup` of `"."` where its plain group is a
  no-break space.

  `Localize.Number.Symbol` had no fields for either, so `struct/2` dropped
  them when the locale data was generated and both locales formatted currency
  with their plain separators (#52). A currency with a separator of its own,
  such as the Cape Verdean escudo, takes precedence over both (#54).

  """

  use ExUnit.Case, async: true

  alias Localize.Number
  alias Localize.Number.Symbol

  describe "a locale whose currency separators differ from its plain ones" do
    test "fr-CH writes a currency amount with a dot decimal" do
      assert {:ok, "1'234.56 CHF"} =
               Number.to_string(Decimal.new("1234.56"), locale: :"fr-CH", currency: :CHF)
    end

    test "fr-CH writes a plain number with a comma decimal" do
      assert {:ok, "1'234,56"} = Number.to_string(Decimal.new("1234.56"), locale: :"fr-CH")
    end

    test "de-AT writes a currency amount with a dot group" do
      assert {:ok, "€ 1.234,56"} =
               Number.to_string(Decimal.new("1234.56"), locale: :"de-AT", currency: :EUR)
    end

    test "de-AT writes a plain number with a space group" do
      assert {:ok, "1 234,56"} = Number.to_string(Decimal.new("1234.56"), locale: :"de-AT")
    end
  end

  describe "the generated locale data" do
    test "carries the currency separators CLDR gives fr-CH and de-AT" do
      {:ok, swiss} = Symbol.number_symbols_for(:"fr-CH", :latn)
      assert swiss.currency_decimal == "."
      assert swiss.currency_group == nil

      {:ok, austrian} = Symbol.number_symbols_for(:"de-AT", :latn)
      assert austrian.currency_group == "."
      assert austrian.currency_decimal == nil
    end

    test "leaves them nil for a locale CLDR gives none" do
      {:ok, symbols} = Symbol.number_symbols_for(:en, :latn)
      assert symbols.currency_decimal == nil
      assert symbols.currency_group == nil
    end
  end

  describe "for_currency/2" do
    test "puts the locale's currency separators in place of the plain ones" do
      {:ok, symbols} = Symbol.number_symbols_for(:"fr-CH", :latn)
      {:ok, currency} = Localize.Currency.currency_for_code(:CHF, locale: :"fr-CH")

      assert Symbol.for_currency(symbols, currency).decimal == "."
    end

    test "a currency's own decimal separator takes precedence" do
      {:ok, symbols} = Symbol.number_symbols_for(:"fr-CH", :latn)
      {:ok, currency} = Localize.Currency.currency_for_code(:CHF, locale: :"fr-CH")
      own = %{currency | decimal_separator: "!"}

      assert Symbol.for_currency(symbols, own).decimal == "!"
    end

    test "leaves a locale with no currency separators unchanged" do
      {:ok, symbols} = Symbol.number_symbols_for(:en, :latn)
      {:ok, currency} = Localize.Currency.currency_for_code(:USD, locale: :en)

      for_currency = Symbol.for_currency(symbols, currency)
      assert for_currency.decimal == symbols.decimal
      assert for_currency.group == symbols.group
    end
  end

  describe "locales CLDR gives no currency separators" do
    test "write currency amounts as they did before" do
      assert {:ok, "$1,234.56"} =
               Number.to_string(Decimal.new("1234.56"), locale: :en, currency: :USD)

      assert {:ok, "1.234,56 €"} =
               Number.to_string(Decimal.new("1234.56"), locale: :de, currency: :EUR)
    end
  end
end
