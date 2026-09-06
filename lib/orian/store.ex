defmodule Orian.Store do
  @moduledoc "ETS / S3 / S5 blob store. Prefer `Orian.put/2` and `Orian.get/2`."

  @table :orian_memory

  def put(data, opts \\ []) when is_binary(data) do
    cid = Orian.CID.of(data)
    xxh = Orian.xxh3(data)

    case Keyword.get(opts, :backend, :memory) do
      :memory ->
        ensure_table()
        :ets.insert(@table, {cid.hash, data, cid.size, xxh})
        {:ok, cid}

      :s3 ->
        Orian.S3.put(data, Keyword.put(opts, :cid, cid))

      :s5 ->
        Orian.S5.put(data, Keyword.put(opts, :cid, cid))
    end
  end

  def get(cid, opts \\ [])

  def get(%Orian.CID{hash: hash} = cid, opts) do
    case Keyword.get(opts, :backend, :memory) do
      :memory ->
        ensure_table()

        case :ets.lookup(@table, hash) do
          [{^hash, data, _, _}] -> verify(data, cid)
          [] -> {:error, :not_found}
        end

      :s3 ->
        Orian.S3.get(cid, opts)

      :s5 ->
        Orian.S5.get(cid, opts)
    end
  end

  def get(hash, opts) when is_binary(hash) and byte_size(hash) == 32 do
    get(%Orian.CID{hash: hash, size: nil, algo: :blake3}, opts)
  end

  def verify(data, %Orian.CID{hash: hash}) when is_binary(data) do
    if Orian.blake3(data) == hash, do: {:ok, data}, else: {:error, :integrity}
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> @table
    end
  end
end
