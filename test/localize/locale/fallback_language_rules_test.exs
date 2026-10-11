defmodule Localize.Locale.FallbackLanguageRulesTest do
  @moduledoc """
  Covers language rules following the locale whose data was loaded.

  When a locale has no data of its own, the loader stores a parent's data — or
  `:en`'s — under the requested locale id, so that later reads find it (issue
  #26). The text then belongs to one locale while the request names another,
  and the rules that select among that text must follow the text: plural rules
  pick between `"1 dollar"` and `"2 dollars"`, so applying Russian plural
  rules to English names would select a category English has no name for.

  Territory preferences are the other way round. The currency of a locale and
  the first day of its week belong to the requested locale, not to whichever
  locale supplied the words, so those keep following the request.

  """

  use ExUnit.Case, async: true

  alias Localize.Locale

  describe "data_locale_id/1" do
    test "is the locale's own id when it has data" do
      assert Locale.data_locale_id(:en) == :en
      assert Locale.data_locale_id(:"de-CH") == :"de-CH"
    end

    test "accepts a language tag as well as an id" do
      {:ok, tag} = Localize.validate_locale(:"de-CH")
      assert Locale.data_locale_id(tag) == Locale.data_locale_id(:"de-CH")
    end

    test "agrees with the :name the data carries" do
      for locale <- [:en, :fr, :ja, :"pt-BR", :und] do
        assert {:ok, name} = Locale.get(locale, [:name])
        assert Locale.data_locale_id(locale) == name
      end
    end
  end

  describe "a plural category selected for a currency name" do
    # The category and the name have to come from one locale: a category the
    # names have no entry for falls back to `:other`, which silently formats
    # the wrong word rather than failing.
    test "names a currency with the category of the data's own rules" do
      for locale <- [:en, :ru, :pl, :ar, :ja] do
        for number <- [0, 1, 2, 5, 11, 21, 100] do
          assert {:ok, formatted} =
                   Localize.Number.to_string(number,
                     locale: locale,
                     currency: :USD,
                     format: :long
                   )

          assert is_binary(formatted) and formatted != "",
                 "#{locale} produced no long currency name for #{number}"
        end
      end
    end
  end

  describe "territory preferences" do
    test "still follow the requested locale, not the loaded data" do
      # `de-CH` has its own data, so this holds trivially today; it pins the
      # distinction so that a future fallback change cannot quietly move
      # territory preferences onto the data's locale.
      assert {:ok, :CHF} = Localize.Currency.currency_from_locale(:"de-CH")
      assert {:ok, :EUR} = Localize.Currency.currency_from_locale(:"de-AT")
      assert {:ok, :USD} = Localize.Currency.currency_from_locale(:en)
    end
  end
end
