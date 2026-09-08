defmodule Orian.Adapters.GCS do
  @moduledoc """
  Google Cloud Storage adapter for Orian.

  Reuses existing S3 XML parsing with GCS-specific endpoint and auth.
  """

  @behaviour Orian.S3.Behaviour

  @impl true
  def list_objects(bucket, prefix, opts) do
    endpoint = Keyword.get(opts, :endpoint, "https://storage.googleapis.com")
    # Reuse S3 XML parsing with GCS endpoint
    Orian.S3.list_objects(bucket, prefix, Keyword.merge(opts, endpoint: endpoint))
  end

  @impl true
  def get_object(bucket, key, opts) do
    endpoint = Keyword.get(opts, :endpoint, "https://storage.googleapis.com")
    Orian.S3.get_object(bucket, key, Keyword.merge(opts, endpoint: endpoint))
  end

  @impl true
  def put_object(bucket, key, body, opts) do
    endpoint = Keyword.get(opts, :endpoint, "https://storage.googleapis.com")
    Orian.S3.put_object(bucket, key, body, Keyword.merge(opts, endpoint: endpoint))
  end
end
