defmodule DiagramForge.AI.CacheServer do
  @moduledoc """
  Supervised GenServer that owns the prompt cache ETS table.

  By wrapping the ETS table in a GenServer under the supervision tree,
  the cache lifecycle is properly tied to the application lifecycle.
  If the supervision tree restarts, the cache is recreated fresh.

  The ETS table is public with read_concurrency enabled for performance -
  direct ETS access is used for get/put operations to avoid GenServer
  bottleneck on reads.
  """
  use GenServer

  @table_name :prompt_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    table = :ets.new(@table_name, [:named_table, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @doc """
  Returns the ETS table name for direct access.
  """
  def table_name, do: @table_name

  @doc """
  Gets a value from the cache.
  Returns `{:ok, value}` if found, `:miss` if not found.
  """
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :miss
    end
  end

  @doc """
  Puts a value in the cache.
  """
  def put(key, value) do
    :ets.insert(@table_name, {key, value})
    :ok
  end

  @doc """
  Deletes a key from the cache.
  """
  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  @doc """
  Deletes all entries from the cache.
  """
  def delete_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end
end
