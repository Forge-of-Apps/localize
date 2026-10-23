defmodule Localize.Locale.StaleLocaleWarningTest do
  # async: false because the once-only warning is recorded in
  # :persistent_term, which every test shares.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  # A provider whose cached `de-CH` is stale and cannot be refreshed, as
  # it is after an upgrade when runtime downloads are off, and whose `:en`
  # loads.
  defmodule StaleProvider do
    def load(:en), do: {:ok, %{version: Localize.version()}}

    def load(locale) do
      {:error,
       Localize.LocaleIsStaleError.exception(
         locale_id: locale,
         cached_version: Version.parse!("48.2.2"),
         current_version: Localize.version()
       )}
    end
  end

  @warned_key {{:localize, :stale_locale_warned}, :"de-CH"}

  setup do
    :persistent_term.erase(@warned_key)
    on_exit(fn -> :persistent_term.erase(@warned_key) end)
    :ok
  end

  test "a stale locale that falls back is reported once at warning level" do
    log =
      capture_log([level: :warning], fn ->
        Localize.Locale.Provider.load_with_fallback(StaleProvider, :"de-CH")
        Localize.Locale.Provider.load_with_fallback(StaleProvider, :"de-CH")
      end)

    assert log =~ "has CLDR data version 48.2.2"
    assert log =~ "mix localize.download_locales"
    assert [_before, _after] = String.split(log, "has CLDR data version 48.2.2")
  end

  test "a locale that is simply missing is not reported as stale" do
    defmodule MissingProvider do
      def load(:en), do: {:ok, %{}}

      def load(locale),
        do: {:error, Localize.LocaleNotFoundInCacheError.exception(locale_id: locale)}
    end

    log =
      capture_log([level: :warning], fn ->
        Localize.Locale.Provider.load_with_fallback(MissingProvider, :"de-CH")
      end)

    refute log =~ "CLDR data version"
  end
end
