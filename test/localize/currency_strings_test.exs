defmodule Localize.CurrencyStringsTest do
  @moduledoc """
  Covers the index from the strings that name a currency to its code.

  Every name, symbol, code and plural form a locale gives a currency is a
  string the number parser may have to recognise, so they are indexed. Building
  that index walks every currency the locale knows and costs about 1.2 ms, so
  the data pipeline builds it once with the locale data and
  `Localize.Currency.currency_strings/2` reads it — about 0.6 µs — rather than
  building it per call or caching it.

  A filter cannot be applied to the stored index by selecting from it, because
  a filter changes which strings are *unambiguous*: `"kr"` names no single
  currency among all of them, and names the Norwegian krone alone among
  `only: [:NOK]`. A filtered call is therefore still built from the currencies
  the filter leaves.

  """

  use ExUnit.Case, async: true

  alias Localize.Currency

  describe "the unfiltered index" do
    test "is the one generated with the locale data" do
      for locale <- [:en, :fr, :ja, :ar, :"de-CH"] do
        assert {:ok, generated} = Localize.Locale.get(locale, [:currency_strings])
        assert {:ok, ^generated} = Currency.currency_strings(locale)
      end
    end

    test "is read for the filter forms that select every currency" do
      {:ok, bare} = Currency.currency_strings(:en)

      # What `Localize.Number.Parser.resolve_currency/2` passes by default.
      assert {:ok, ^bare} = Currency.currency_strings(:en, only: [:all], except: [])
      assert {:ok, ^bare} = Currency.currency_strings(:en, only: :all)
      assert {:ok, ^bare} = Currency.currency_strings(:en, [])
    end

    test "indexes names, symbols and codes" do
      {:ok, strings} = Currency.currency_strings(:en)

      assert Map.get(strings, "us dollar") == :USD
      assert Map.get(strings, "usd") == :USD
      assert Map.get(strings, "$") == :USD
      assert Map.get(strings, "euro") == :EUR
    end

    test "leaves out a string several currencies claim" do
      {:ok, strings} = Currency.currency_strings(:en)

      # "kr" is claimed by the Norwegian, Swedish, Danish and Icelandic
      # currencies among others, so it names none of them on its own.
      refute Map.has_key?(strings, "kr")
    end

    test "differs by locale" do
      {:ok, english} = Currency.currency_strings(:en)
      {:ok, arabic} = Currency.currency_strings(:ar)

      refute english == arabic
    end
  end

  describe "a filtered index" do
    test "is built from the currencies the filter leaves" do
      {:ok, strings} = Currency.currency_strings(:en, only: [:NOK])

      assert Map.get(strings, "nok") == :NOK
      refute Map.has_key?(strings, "usd")
    end

    test "resolves a string that is ambiguous among all currencies" do
      # The point of filtering: "kr" names the krone once the others are gone.
      assert {:ok, %{"kr" => :NOK}} = Currency.currency_strings(:en, only: [:NOK])
    end

    test "does not disturb the unfiltered index" do
      {:ok, before} = Currency.currency_strings(:en)
      {:ok, _filtered} = Currency.currency_strings(:en, only: [:NOK])

      assert {:ok, ^before} = Currency.currency_strings(:en)
    end

    test "an :except filter leaves the rest" do
      {:ok, strings} = Currency.currency_strings(:en, except: [:USD])

      refute Map.get(strings, "us dollar") == :USD
      assert Map.get(strings, "euro") == :EUR
    end
  end

  describe "the number parser" do
    test "resolves a currency from each of its strings" do
      for string <- ["US dollar", "USD", "euro", "Japanese yen"] do
        assert [_ | _] = Localize.Number.Parser.resolve_currency(string, locale: :en),
               "#{inspect(string)} resolved to no currency"
      end
    end
  end
end
