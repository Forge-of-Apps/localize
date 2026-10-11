defmodule Localize.Unit.PreferenceTest do
  use ExUnit.Case, async: true

  alias Localize.Test.PreferenceData

  doctest Localize.Unit.Preference

  describe "usage option hardening" do
    test "an unknown usage string falls back to default preferences" do
      unit = Localize.Unit.new!(100, "meter")

      assert Localize.Unit.Preference.preferred_units(unit, usage: "no-such-usage-exists") ==
               Localize.Unit.Preference.preferred_units(unit, usage: :default)
    end

    test "an unknown usage string does not create a new atom" do
      unit = Localize.Unit.new!(100, "meter")
      unique = "usage_atom_probe_#{System.unique_integer([:positive])}"

      {:ok, _units, _options} =
        Localize.Unit.Preference.preferred_units(unit, usage: unique)

      assert_raise ArgumentError, fn ->
        String.to_existing_atom(unique)
      end
    end
  end

  describe "the -u-mu measurement unit override" do
    # BCP-47 caps a key's value at eight characters, so CLDR spells the
    # Fahrenheit override `fahrenhe` (`common/bcp47/measure.xml`, key `mu`).
    # Read as a unit identifier it names no unit, so the override used to be
    # dropped as not convertible and the locale's own preference stood.
    # CLDR's own `unitLocalePreferencesTest.txt` carries only `mu-celsius`
    # cases, where the value and the unit happen to be spelled alike, so the
    # fixture never caught it.
    test "fahrenhe names Fahrenheit" do
      unit = Localize.Unit.new!(20, "celsius")

      assert {:ok, [:fahrenheit], []} =
               Localize.Unit.Preference.preferred_units(unit, locale: "de-u-mu-fahrenhe")
    end

    test "celsius and kelvin name themselves" do
      unit = Localize.Unit.new!(20, "fahrenheit")

      assert {:ok, [:celsius], []} =
               Localize.Unit.Preference.preferred_units(unit, locale: "de-u-mu-celsius")

      assert {:ok, [:kelvin], []} =
               Localize.Unit.Preference.preferred_units(unit, locale: "de-u-mu-kelvin")
    end

    test "an override not convertible from the input unit is ignored" do
      # TR35: "mu > ms > rg > (likely) region", but only where the override
      # is convertible — a length asked for in Fahrenheit stays a length.
      assert {:ok, [:meter], []} =
               Localize.Unit.Preference.preferred_units(
                 Localize.Unit.new!(1, "meter"),
                 locale: "de-u-mu-fahrenhe"
               )

      assert {:ok, [:centimeter], []} =
               Localize.Unit.Preference.preferred_units(
                 Localize.Unit.new!(1, "foot"),
                 locale: "de-u-mu-celsius"
               )
    end

    test "a locale carrying no -u- extension keeps its own preference" do
      unit = Localize.Unit.new!(20, "celsius")

      assert {:ok, [:celsius], []} =
               Localize.Unit.Preference.preferred_units(unit, locale: :de)

      assert {:ok, [:fahrenheit], []} =
               Localize.Unit.Preference.preferred_units(unit, locale: :en)
    end

    test "the override reaches the localized unit" do
      assert {:ok, [%Localize.Unit{name: "fahrenheit", value: value}]} =
               Localize.Unit.localize(Localize.Unit.new!(20, "celsius"),
                 locale: "de-u-mu-fahrenhe"
               )

      assert_in_delta value, 68.0, 0.0001
    end
  end

  for t <- PreferenceData.preferences() do
    test_name =
      "##{t.line}: preference for #{inspect(t.input_unit)} with usage #{inspect(t.usage)} " <>
        "in region #{inspect(t.region)} for #{inspect(t.input_double)} " <>
        "is #{inspect(t.output_units)}"

    test test_name do
      assert {:ok, units, _skeleton} =
               Localize.Unit.Preference.preferred_units(
                 Localize.Unit.new!(unquote(t.input_double), unquote(t.input_unit)),
                 usage: unquote(t.usage),
                 territory: unquote(t.region)
               )

      assert Enum.map(units, &to_string/1) == unquote(t.output_units)
    end
  end
end
