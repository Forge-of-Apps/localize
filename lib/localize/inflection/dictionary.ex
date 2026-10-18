defmodule Localize.Inflection.Dictionary do
  @moduledoc """
  Low-level access to the lexical dictionary for a locale.

  Words map to grammatical properties (grammemes) represented as
  integer bitmasks, and to the inflection patterns they belong to.
  This module mirrors the upstream `DictionaryMetaData` and
  `DictionaryExposableMorphology` APIs.

  """

  # The per-language synthesizers and conformance harnesses are ported
  # from the upstream C++ linguistic rule tables; their branchiness and
  # nesting mirror the reference implementation they are verified
  # against (see guides/inflection.md).
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting

  alias Localize.Inflection.Data

  import Bitwise

  @doc """
  Returns the combined grammeme bitmask for a surface form, or nil
  if the word is not in the dictionary.

  ### Arguments

  * `locale` is any locale atom for which data has been generated.

  * `word` is the surface form to look up.

  ### Returns

  * The combined bitmask of all grammemes of all readings of
    `word`, or nil if `word` is unknown.

  ### Examples

      iex> mask = Localize.Inflection.Dictionary.combined_grammemes(:en, "cats")
      iex> Enum.sort(Localize.Inflection.Dictionary.property_names(:en, mask))
      ["consonant-start", "noun", "plural", "present", "simple", "singular", "third", "verb"]

      iex> Localize.Inflection.Dictionary.combined_grammemes(:en, "xyzzy")
      nil

  """
  def combined_grammemes(locale, word) do
    case Data.lookup(locale, word) do
      {mask, _patterns} -> mask
      nil -> nil
    end
  end

  @doc """
  Returns the combined bitmask for a list of grammeme names.

  Names unknown to the locale are skipped, as upstream: the Arabic
  definiteness lookup asks for "definite" although no dictionary
  entry carries it.

  ### Arguments

  * `locale` is a locale identifier.

  * `names` is a list of grammeme names, such as `["noun", "plural"]`.

  ### Returns

  * The combined bitmask, or `nil` when none of the names is known.

  ### Examples

      iex> mask = Localize.Inflection.Dictionary.binary_properties(:en, ["noun", "plural"])
      iex> Localize.Inflection.Dictionary.has_all_properties?(:en, "cats", mask)
      true

      iex> Localize.Inflection.Dictionary.binary_properties(:en, ["not-a-grammeme"])
      nil

  """
  def binary_properties(locale, names) when is_list(names) do
    case Data.metadata(locale) do
      {:ok, %{grammeme_bits: bits}} -> names_mask(names, bits)
      _no_metadata -> nil
    end
  end

  def binary_properties(_locale, _names), do: nil

  defp names_mask(names, bits) do
    mask =
      Enum.reduce(names, 0, fn name, acc ->
        case Map.fetch(bits, name) do
          {:ok, bit} -> acc ||| 1 <<< bit
          :error -> acc
        end
      end)

    if mask == 0, do: nil, else: mask
  end

  @doc """
  Returns the grammeme name for a mask with exactly one bit set.

  ### Arguments

  * `locale` is a locale identifier.

  * `mask` is a grammeme bitmask.

  ### Returns

  * The grammeme name, or `nil` when `mask` does not have exactly one
    bit set or names no grammeme of the locale.

  ### Examples

      iex> mask = Localize.Inflection.Dictionary.binary_properties(:en, ["plural"])
      iex> Localize.Inflection.Dictionary.property_name(:en, mask)
      "plural"

  """
  def property_name(_locale, 0), do: nil

  def property_name(locale, mask) when is_integer(mask) and mask > 0 do
    if single_bit?(mask), do: named_grammeme(locale, mask)
  end

  def property_name(_locale, _mask), do: nil

  # `nil` where the locale has no inflection data, or where the bit is beyond
  # the names it holds.
  defp named_grammeme(locale, mask) do
    case Data.metadata(locale) do
      {:ok, %{grammeme_names: names}} -> name_at(names, bit_index(mask))
      {:error, _no_data} -> nil
    end
  end

  defp name_at(names, index) when index < tuple_size(names), do: elem(names, index)
  defp name_at(_names, _index), do: nil

  @doc """
  Returns the list of grammeme names present in `mask`.

  ### Arguments

  * `locale` is a locale identifier.

  * `mask` is a grammeme bitmask.

  ### Returns

  * A list of grammeme names, empty where the locale has no
    inflection data.

  ### Examples

      iex> mask = Localize.Inflection.Dictionary.binary_properties(:en, ["noun", "plural"])
      iex> Enum.sort(Localize.Inflection.Dictionary.property_names(:en, mask))
      ["noun", "plural"]

  """
  def property_names(locale, mask) when is_integer(mask) do
    case Data.metadata(locale) do
      {:ok, %{grammeme_names: names}} ->
        for bit <- 0..(tuple_size(names) - 1)//1, (mask >>> bit &&& 1) == 1, do: elem(names, bit)

      _no_metadata ->
        []
    end
  end

  def property_names(_locale, _mask), do: []

  @doc """
  Returns true if the word has all the properties in `mask`.

  ### Arguments

  * `locale` is a locale identifier.

  * `word` is the word to look up.

  * `mask` is a grammeme bitmask.

  ### Returns

  * `true` when the word's combined grammemes include every bit of
    `mask`, and `false` otherwise or when the word is unknown.

  ### Examples

      iex> mask = Localize.Inflection.Dictionary.binary_properties(:en, ["noun", "plural"])
      iex> Localize.Inflection.Dictionary.has_all_properties?(:en, "cats", mask)
      true
      iex> Localize.Inflection.Dictionary.has_all_properties?(:en, "xyzzy", mask)
      false

  """
  def has_all_properties?(locale, word, mask) when is_integer(mask) do
    case combined_grammemes(locale, word) do
      nil -> false
      combined -> (combined &&& mask) == mask
    end
  end

  def has_all_properties?(_locale, _word, _mask), do: false

  @doc """
  Returns the inflection patterns for a word.

  ### Arguments

  * `locale` is a locale identifier.

  * `word` is the word to look up.

  ### Returns

  * A list of pattern maps, each with `:name`, `:inflections`,
    `:pos_mask` and `:lemma_suffix`, or `[]` when the word is unknown
    or uninflectable.

  ### Examples

      iex> length(Localize.Inflection.Dictionary.patterns_for_word(:en, "cats"))
      2
      iex> Localize.Inflection.Dictionary.patterns_for_word(:en, "xyzzy")
      []

  """
  def patterns_for_word(locale, word) do
    case Data.lookup(locale, word) do
      {_mask, pattern_indexes} ->
        patterns = Data.metadata!(locale).patterns
        Enum.map(pattern_indexes, &elem(patterns, &1))

      nil ->
        []
    end
  end

  @doc """
  Returns the grammeme bitmask sets for each reading of a word.

  A word that belongs to inflection patterns gets one grammeme set
  per matching inflection row (the row grammemes combined with the
  pattern part of speech). A word without patterns returns its
  combined grammemes as the single set.

  ### Arguments

  * `locale` is a locale identifier.

  * `word` is the word to look up.

  ### Returns

  * A list of grammeme bitmasks, one for each reading, or `[]` when
    the word is unknown.

  ### Examples

      iex> for set <- Localize.Inflection.Dictionary.grammeme_sets(:en, "cats") do
      ...>   Enum.sort(Localize.Inflection.Dictionary.property_names(:en, set))
      ...> end
      [["present", "simple", "singular", "third", "verb"], ["noun", "plural"]]

  """
  def grammeme_sets(locale, word) do
    case Data.lookup(locale, word) do
      nil ->
        []

      {combined, []} ->
        [combined]

      {combined, pattern_indexes} ->
        patterns = Data.metadata!(locale).patterns

        sets =
          Enum.flat_map(pattern_indexes, fn index ->
            pattern = elem(patterns, index)

            case pattern.inflections do
              [] ->
                [pattern.pos_mask]

              _inflections ->
                word
                |> matching_inflections(combined, pattern)
                |> Enum.map(fn {grammemes, _suffix} -> grammemes ||| pattern.pos_mask end)
            end
          end)

        if sets == [], do: [combined], else: sets
    end
  end

  @doc """
  Returns the inflection rows of `pattern` that could have produced
  `surface_form` given the word's combined grammemes.

  Only rows whose grammemes are a subset of `from_grammemes` and
  whose suffix is a suffix of the surface form qualify; among those,
  only the rows with the longest matching suffix are returned.

  ### Arguments

  * `surface_form` is the word as written.

  * `from_grammemes` is the word's combined grammeme bitmask.

  * `pattern` is a pattern map from `patterns_for_word/2`.

  ### Returns

  * A list of `{grammemes, suffix}` rows, or `[]` when none qualifies.

  ### Examples

      iex> [pattern | _rest] = Localize.Inflection.Dictionary.patterns_for_word(:en, "cats")
      iex> grammemes = Localize.Inflection.Dictionary.combined_grammemes(:en, "cats")
      iex> for {_grammemes, suffix} <-
      ...>       Localize.Inflection.Dictionary.matching_inflections("cats", grammemes, pattern),
      ...>     do: suffix
      ["s"]

  """
  def matching_inflections(surface_form, from_grammemes, %{inflections: inflections})
      when is_binary(surface_form) and is_integer(from_grammemes) and is_list(inflections) do
    {matches, _max_length} =
      Enum.reduce(inflections, {[], -1}, fn {grammemes, suffix} = inflection,
                                            {matches, max_length} = acc ->
        length = byte_size(suffix)

        cond do
          (from_grammemes &&& grammemes) != grammemes -> acc
          length < max_length or not String.ends_with?(surface_form, suffix) -> acc
          length > max_length -> {[inflection], length}
          true -> {[inflection | matches], max_length}
        end
      end)

    Enum.reverse(matches)
  end

  def matching_inflections(_surface_form, _from_grammemes, _pattern), do: []

  defp single_bit?(mask), do: (mask &&& mask - 1) == 0

  defp bit_index(mask), do: bit_index(mask, 0)
  defp bit_index(1, index), do: index
  defp bit_index(mask, index), do: bit_index(mask >>> 1, index + 1)
end
