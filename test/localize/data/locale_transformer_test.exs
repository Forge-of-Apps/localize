defmodule Localize.Data.LocaleTransformerTest do
  @moduledoc """
  Covers the locale transformer refusing data its structs do not define.

  The transformer builds `Localize.Number.Symbol`, `Localize.Number.Format`
  and `Localize.Currency` structs from normalized CLDR data. It used `struct/2`,
  which drops any key the struct does not define — so CLDR's `currencyDecimal`
  and `currencyGroup` were normalized and then silently discarded, and `fr-CH`
  and `de-AT` formatted currency amounts with their plain separators (#52).

  `struct!/2` makes that impossible: a key the struct does not know fails the
  generation rather than being thrown away, which matters most when a new CLDR
  release adds one. Symbols no formatter uses are left out by name, in
  `@excluded_symbols`, so the refusal is a decision rather than an accident.

  """

  use ExUnit.Case, async: true

  alias Localize.Data.LocaleTransformer

  describe "transform_number_symbols/1" do
    test "builds a Symbol struct from the keys it defines" do
      raw = %{"latn" => %{decimal: ",", group: ".", currency_decimal: "."}}

      assert %{latn: %Localize.Number.Symbol{} = symbols} =
               LocaleTransformer.transform_number_symbols(raw)

      assert symbols.decimal == ","
      assert symbols.group == "."
      assert symbols.currency_decimal == "."
    end

    test "a symbol that CLDR adds and the struct does not know fails the generation" do
      raw = %{"latn" => %{decimal: ",", digit_marker: "!"}}

      assert_raise KeyError, ~r/key :digit_marker not found/, fn ->
        LocaleTransformer.transform_number_symbols(raw)
      end
    end

    test "an excluded symbol is dropped rather than failing" do
      # `time_separator_alt_variant` is in `@excluded_symbols`: no formatter
      # reads it, so it is left out deliberately.
      raw = %{"latn" => %{decimal: ",", time_separator_alt_variant: "."}}

      assert %{latn: %Localize.Number.Symbol{decimal: ","}} =
               LocaleTransformer.transform_number_symbols(raw)
    end
  end
end
