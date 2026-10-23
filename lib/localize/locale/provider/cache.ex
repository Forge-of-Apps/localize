defmodule Localize.Locale.Provider.Cache do
  @moduledoc """
  On-disk cache for downloaded locale data files.

  This module is responsible for reading and writing locale ETF
  files under the directory returned by
  `Localize.Locale.Provider.locale_cache_dir/0`, and for detecting
  when a cached file is stale: of another version than
  `Localize.version/0`, or not the bytes the release's hash manifest
  records for it.

  ## Primary API

  * `get/1` — returns cached locale data, or an error tuple if the
    file is missing or stale.

  * `store/2` — writes locale data to the cache directory.

  * `stale?/1` — checks whether a cached locale file is stale.

  * `path/1` — returns the absolute path for a locale's cache file.

  """

  alias Localize.Locale.Provider

  @typedoc "A locale identifier as an atom."
  @type locale_id :: atom()

  @doc """
  Returns the absolute cache file path for the given locale.

  ### Arguments

  * `locale_id` is a locale identifier atom.

  ### Returns

  * A string path to the locale's cache file.

  ### Examples

      iex> path = Localize.Locale.Provider.Cache.path(:en)
      iex> String.ends_with?(path, "en.etf")
      true

  """
  @spec path(locale_id()) :: String.t()
  def path(locale_id) when is_atom(locale_id) do
    Path.join(Provider.locale_cache_dir(), Provider.locale_file_name(locale_id))
  end

  @doc """
  Retrieves locale data from the cache directory.

  Reads the locale's cache file, decodes it, and validates that
  its `:version` field matches `Localize.version/0` and that its bytes
  match the SHA-256 hash the release's manifest records for it.

  ### Arguments

  * `locale_id` is a locale identifier atom.

  ### Returns

  * `{:ok, locale_data}` if the cache file is present, its version
    matches the current version and its bytes match the manifest.

  * `{:error, Localize.LocaleIsStaleError.t()}` if the cache file
    is present but its version or its bytes do not match.

  * `{:error, Localize.LocaleNotFoundInCacheError.t()}` if the
    cache file is not present.

  * `{:error, exception}` if `locale_id` is not an atom.

  ### Examples

      iex> {:error, error} = Localize.Locale.Provider.Cache.get(:"zz-ZZ")
      iex> error.__struct__
      Localize.LocaleNotFoundInCacheError

  """
  @spec get(locale_id()) ::
          {:ok, map()} | {:error, Exception.t()}
  def get(locale_id) when is_atom(locale_id) do
    cache_dir = Provider.locale_cache_dir()
    bundled_dir = Provider.default_locale_cache_dir()
    file_name = Provider.locale_file_name(locale_id)

    search_paths =
      if cache_dir == bundled_dir do
        [Path.join(cache_dir, file_name)]
      else
        [Path.join(cache_dir, file_name), Path.join(bundled_dir, file_name)]
      end

    read_first(locale_id, search_paths)
  end

  def get(locale_id),
    do: {:error, Localize.Utils.Helpers.invalid_value(locale_id, "a locale identifier atom")}

  defp read_first(locale_id, [file_path]) do
    read_and_validate(locale_id, file_path)
  end

  defp read_first(locale_id, [file_path | rest]) do
    case read_and_validate(locale_id, file_path) do
      {:ok, _locale_data} = success ->
        success

      # A stale file in an earlier search path is the more specific
      # diagnosis: the locale *is* cached, just at the wrong data
      # version. Keep it rather than reporting the last path's
      # "not found", which sends the reader looking for a missing file.
      {:error, %Localize.LocaleIsStaleError{}} = stale ->
        case read_first(locale_id, rest) do
          {:ok, _locale_data} = success -> success
          {:error, _later} -> stale
        end

      {:error, _reason} ->
        read_first(locale_id, rest)
    end
  end

  defp read_and_validate(locale_id, file_path) do
    case File.read(file_path) do
      {:ok, binary} ->
        case decode_etf(binary) do
          {:ok, locale_data} ->
            validated(locale_id, binary, locale_data)

          {:error, :undecodable} ->
            # A corrupt or truncated cache file (torn write, disk
            # corruption) is a cache miss, not a crash — callers fall
            # back to download or the bundled data.
            {:error,
             Localize.LocaleNotFoundInCacheError.exception(
               locale_id: locale_id,
               path: file_path
             )}
        end

      {:error, :enoent} ->
        {:error,
         Localize.LocaleNotFoundInCacheError.exception(
           locale_id: locale_id,
           path: file_path
         )}

      {:error, reason} ->
        {:error,
         Localize.LocaleNotFoundInCacheError.exception(
           locale_id: locale_id,
           path: file_path,
           posix_error: reason
         )}
    end
  end

  # `binary_to_term/1` raises on anything that is not a complete,
  # well-formed external term and has no variant that returns an error,
  # so it runs in a process of its own and corrupt file content comes
  # back as an error.
  defp decode_etf(binary) do
    case Localize.Utils.Helpers.run_isolated(fn -> :erlang.binary_to_term(binary) end) do
      {:ok, term} -> {:ok, term}
      {:error, _exception} -> {:error, :undecodable}
    end
  end

  defp validated(locale_id, binary, locale_data) do
    with {:ok, locale_data} <- validate_version(locale_id, locale_data) do
      validate_content(locale_id, binary, locale_data)
    end
  end

  # A file of the current version is current only when its bytes are the
  # ones the release's hash manifest records for the locale, so a file
  # written for this data version before it was final is refreshed too.
  # Where there is no manifest, or no entry for the locale, the version
  # alone decides, as it does for a download.
  defp validate_content(locale_id, binary, locale_data) do
    case expected_hash(locale_id) do
      nil -> {:ok, locale_data}
      expected -> content_matches(locale_id, binary, locale_data, expected)
    end
  end

  defp expected_hash(locale_id) do
    case Provider.locale_hashes() do
      %{} = hashes -> Map.get(hashes, locale_id)
      _no_manifest -> nil
    end
  end

  defp content_matches(locale_id, binary, locale_data, expected) do
    if :crypto.hash(:sha256, binary) == expected do
      {:ok, locale_data}
    else
      {:error,
       Localize.LocaleIsStaleError.exception(
         locale_id: locale_id,
         cached_version: Map.get(locale_data, :version),
         current_version: Localize.version(),
         reason: :content
       )}
    end
  end

  defp validate_version(locale_id, locale_data) do
    current_version = Localize.version()
    cached_version = Map.get(locale_data, :version)

    if versions_match?(cached_version, current_version) do
      {:ok, locale_data}
    else
      {:error,
       Localize.LocaleIsStaleError.exception(
         locale_id: locale_id,
         cached_version: cached_version,
         current_version: current_version
       )}
    end
  end

  @doc """
  Stores locale content in the cache directory.

  Creates the cache directory if it does not already exist and
  writes `content` to the locale's cache file. `content` should
  be the raw binary form of the locale ETF file.

  ### Arguments

  * `locale_id` is a locale identifier atom.

  * `content` is a binary containing the encoded locale data.

  ### Returns

  * `{:ok, path}` where `path` is the absolute path the content
    was written to.

  * `{:error, Localize.LocaleCacheWriteError.t()}` on failure.

  * `{:error, exception}` if `locale_id` is not an atom or `content`
    is not a binary.

  ### Examples

  A store writes the cache file, so the example shows the answer that
  writes nothing, for content that is not a binary:

      iex> Localize.Locale.Provider.Cache.store(:en, :not_a_binary) |> elem(0)
      :error

  """
  @spec store(locale_id(), binary()) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def store(locale_id, content) when is_atom(locale_id) and is_binary(content) do
    file_path = path(locale_id)
    dir = Path.dirname(file_path)

    # Write-then-rename so the cache file appears atomically. A crash
    # or SIGKILL mid-write, or two OS processes sharing a cache dir,
    # can otherwise leave a truncated `.etf` that later reads as
    # corrupt. `File.rename/2` within one directory is atomic on
    # POSIX filesystems. The temp name carries the writer's pid and a
    # unique suffix so concurrent writers never collide.
    temp_path =
      file_path <>
        ".tmp.#{System.pid()}.#{System.unique_integer([:positive])}"

    case written_atomically(dir, temp_path, file_path, content) do
      :ok ->
        {:ok, file_path}

      {:error, reason} ->
        {:error,
         Localize.LocaleCacheWriteError.exception(
           locale_id: locale_id,
           path: file_path,
           posix_error: reason
         )}
    end
  end

  def store(locale_id, content) when is_atom(locale_id),
    do: {:error, Localize.Utils.Helpers.invalid_value(content, "a binary of locale data")}

  def store(locale_id, _content),
    do: {:error, Localize.Utils.Helpers.invalid_value(locale_id, "a locale identifier atom")}

  defp written_atomically(dir, temp_path, file_path, content) do
    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(temp_path, content) do
      rename_or_cleanup(temp_path, file_path)
    end
  end

  defp rename_or_cleanup(temp_path, file_path) do
    case File.rename(temp_path, file_path) do
      :ok ->
        :ok

      {:error, _reason} = error ->
        _ = File.rm(temp_path)
        error
    end
  end

  @doc """
  Returns whether a cached locale file is stale.

  A cache file is considered stale if its `:version` field does
  not equal `Localize.version/0`, or if its bytes do not match the
  SHA-256 hash the release's manifest records for the locale. A file
  that is missing, unreadable, or undecodable (corrupt) is also
  considered stale.

  ### Arguments

  * `locale_id` is a locale identifier atom.

  ### Returns

  * `true` if the cache file is missing, unreadable, or its
    version or bytes do not match.

  * `false` if the cache file is present, its version matches and
    its bytes match the manifest.

  ### Examples

      iex> Localize.Locale.Provider.Cache.stale?(:"xx-NOPE")
      true

  """
  @spec stale?(locale_id()) :: boolean()
  def stale?(locale_id) when is_atom(locale_id) do
    # The same validation `get/1` applies, so a file the download task
    # keeps is one the provider will load. A corrupt file is stale by
    # definition: it will be re-downloaded and rewritten.
    not match?({:ok, _locale_data}, read_and_validate(locale_id, path(locale_id)))
  end

  defp versions_match?(%Version{} = cached, %Version{} = current) do
    Version.compare(cached, current) == :eq
  end

  defp versions_match?(_cached, _current) do
    false
  end
end
