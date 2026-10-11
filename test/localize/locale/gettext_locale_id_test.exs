defmodule Localize.Locale.GettextLocaleIdTest do
  @moduledoc """
  Covers the cached Gettext locale match.

  `gettext_locale_id/2` matches a locale against a backend's known locales,
  which a web application asks on every request and which costs about 18 µs.
  The match is cached, keyed by the locale and by the backend's known locales
  rather than by the backend module, so two backends that know different
  locales cannot be served each other's match and a backend recompiled with
  other locales cannot be served a stale one.

  """

  use ExUnit.Case, async: true

  alias Localize.Locale

  defmodule SwissBackend do
    @moduledoc false
    def __gettext__(:known_locales), do: ["de", "en", "fr", "it"]
    def __gettext__(_), do: nil
  end

  defmodule SwissGermanBackend do
    @moduledoc false
    def __gettext__(:known_locales), do: ["de", "de_CH", "en"]
    def __gettext__(_), do: nil
  end

  describe "a cached match" do
    test "answers the same for each backend on every call" do
      {:ok, tag} = Localize.validate_locale("de-CH")

      # Twice, so the second call reads the cache the first one wrote.
      for _call <- 1..2 do
        assert {:ok, "de"} = Locale.gettext_locale_id(tag, SwissBackend)
        assert {:ok, "de_CH"} = Locale.gettext_locale_id(tag, SwissGermanBackend)
        assert {:ok, "de_CH"} = Locale.gettext_locale_id("de-CH", SwissGermanBackend)
        assert {:ok, "fr"} = Locale.gettext_locale_id(:"fr-CH", SwissBackend)
      end
    end

    test "is keyed by the known locales, so one backend does not shadow another" do
      # Same locale, two backends whose known locales differ: the second must
      # not read the first one's entry.
      assert {:ok, "de"} = Locale.gettext_locale_id("de-CH", SwissBackend)
      assert {:ok, "de_CH"} = Locale.gettext_locale_id("de-CH", SwissGermanBackend)
      assert {:ok, "de"} = Locale.gettext_locale_id("de-CH", SwissBackend)
    end

    test "a distant locale answers the same on a repeated call" do
      # Whatever `best_match/2` makes of a locale the backend does not know,
      # the cached call must agree with the first one.
      first = Locale.gettext_locale_id("zh-Hant", SwissBackend)
      assert Locale.gettext_locale_id("zh-Hant", SwissBackend) == first
    end

    test "a tag, an atom and a string for one locale agree" do
      {:ok, tag} = Localize.validate_locale("fr-CH")

      assert Locale.gettext_locale_id(tag, SwissBackend) ==
               Locale.gettext_locale_id(:"fr-CH", SwissBackend)

      assert Locale.gettext_locale_id("fr-CH", SwissBackend) ==
               Locale.gettext_locale_id(:"fr-CH", SwissBackend)
    end
  end

  describe "a module that is not a Gettext backend" do
    test "is an error rather than a cached match" do
      assert {:error, _} = Locale.gettext_locale_id("de-CH", Enum)
    end
  end
end
