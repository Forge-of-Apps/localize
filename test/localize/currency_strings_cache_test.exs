defmodule Localize.CurrencyStringsCacheTest do
  @moduledoc """
  Covers the cache behind `Localize.Currency.currency_strings/2`.

  The map is built by walking every currency a locale knows and indexing each
  of its names, symbols and codes, which costs about a millisecond. Parsing a
  currency amount needs it, so it is cached per locale and per filter.

  A cached value derived from locale data must not outlive that data.
  `Localize.Locale.store/3` clears the cache, and `Localize.FormatCache.store/3`
  takes the generation read before the build, so a map built from data that was
  replaced while it was being built is dropped rather than cached.

  """

  # Clears the global cache and replaces stored locale data.
  use ExUnit.Case, async: false

  alias Localize.Currency
  alias Localize.FormatCache

  setup do
    on_exit(&FormatCache.clear/0)
    :ok
  end

  describe "a cached map" do
    test "equals the map an uncached call builds" do
      for locale <- [:en, :"de-CH", :ar], options <- [[], [only: :current]] do
        {:ok, first} = Currency.currency_strings(locale, options)
        assert {:ok, ^first} = Currency.currency_strings(locale, options)

        :ok = FormatCache.clear()
        assert {:ok, ^first} = Currency.currency_strings(locale, options)
      end
    end

    test "is keyed by the filter, so a filtered call is not served the unfiltered map" do
      {:ok, all} = Currency.currency_strings(:en)
      refute Map.has_key?(all, "kr")

      assert {:ok, %{"kr" => :NOK}} = Currency.currency_strings(:en, only: [:NOK])

      # And back again: the unfiltered map is still unfiltered.
      assert {:ok, ^all} = Currency.currency_strings(:en)
    end

    test "is keyed by locale" do
      {:ok, english} = Currency.currency_strings(:en)
      {:ok, arabic} = Currency.currency_strings(:ar)

      refute english == arabic
      assert {:ok, ^english} = Currency.currency_strings(:en)
    end
  end

  describe "storing locale data" do
    test "clears the cache, so nothing derived from locale data survives it" do
      # Any value in the cache stands for one derived from locale data.
      {:ok, _strings} = Currency.currency_strings(:en)
      :ok = FormatCache.store({:test, :sentinel}, :present)
      assert {:ok, :present} = FormatCache.lookup({:test, :sentinel})

      assert :ok = Localize.Locale.store(:"zz-cache-test", %{name: :"zz-cache-test"})

      assert :miss = FormatCache.lookup({:test, :sentinel})
    end

    test "advances the generation, so a map built across the store is not cached" do
      # What `cached_currency_strings/3` guards against: the generation is read
      # before the build and checked at the store, so a value built from data
      # that was replaced meanwhile is dropped.
      generation = FormatCache.generation()
      :ok = Localize.Locale.store(:"zz-cache-test", %{name: :"zz-cache-test"})

      assert FormatCache.generation() > generation

      :ok = FormatCache.store({:test, :built_before_store}, :stale, generation)
      assert :miss = FormatCache.lookup({:test, :built_before_store})
    end
  end

  describe "FormatCache.store/3" do
    test "keeps a value stored with the current generation" do
      generation = FormatCache.generation()
      :ok = FormatCache.store({:test, :current}, :kept, generation)

      assert {:ok, :kept} = FormatCache.lookup({:test, :current})
    end

    test "drops a value whose generation is stale" do
      generation = FormatCache.generation()
      :ok = FormatCache.clear()
      :ok = FormatCache.store({:test, :stale}, :dropped, generation)

      assert :miss = FormatCache.lookup({:test, :stale})
    end

    test "always stores without a generation" do
      :ok = FormatCache.clear()
      :ok = FormatCache.store({:test, :any}, :kept)

      assert {:ok, :kept} = FormatCache.lookup({:test, :any})
    end

    test "clear/0 advances the generation" do
      before = FormatCache.generation()
      :ok = FormatCache.clear()

      assert FormatCache.generation() == before + 1
    end
  end
end
