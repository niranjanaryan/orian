defmodule OrianTest do
  use ExUnit.Case, async: false

  test "Zig NIF blake3 and xxh3" do
    assert Orian.nif_loaded?()
    h = Orian.blake3("hello")
    assert byte_size(h) == 32
    assert Orian.blake3("hello") == h
    assert Orian.blake3("hello") != Orian.blake3("world")
    assert is_integer(Orian.xxh3("hello"))
    assert Orian.xxh3("hello") != Orian.xxh3("world")
    assert is_integer(Orian.hash64("hello"))
  end

  test "Rust NIF agrees with Zig on BLAKE3" do
    result =
      try do
        Orian.Rs.blake3("hello")
      rescue
        e -> {:rescued, e}
      end

    assert is_binary(result) and byte_size(result) == 32, inspect(result)
    assert result == Orian.Native.blake3("hello")
    assert Orian.Rs.xxh3("hello") == Orian.Native.xxh3("hello")
  end

  test "memory put/get and S5 CID round-trip" do
    data = "orian blob"
    {:ok, cid} = Orian.put(data)
    assert cid.algo == :blake3
    assert cid.hash == Orian.blake3(data)
    assert {:ok, ^data} = Orian.get(cid)
    encoded = Orian.CID.encode(cid)
    assert {:ok, decoded} = Orian.CID.decode(encoded)
    assert decoded.hash == cid.hash
    assert {:error, :not_found} = Orian.get(Orian.blake3("missing"))
  end

  test "backends map" do
    b = Orian.backends()
    assert b.zig_nif
    assert is_boolean(b.rust_nif)
  end

  test "URI parse s3 gs and local" do
    s = Orian.URI.parse("s3://bkt/a/b.bin")
    assert s.scheme == :s3 and s.bucket == "bkt" and s.key == "a/b.bin"
    g = Orian.URI.parse("gs://g/x")
    assert g.scheme == :gs and g.bucket == "g"
    f = Orian.URI.parse("/tmp/x")
    assert Orian.URI.local?(f)
  end

  test "S3 list XML parse" do
    xml = """
    <ListBucketResult>
      <Contents><Key>a/f.txt</Key><Size>12</Size><ETag>&quot;abc&quot;</ETag></Contents>
      <IsTruncated>false</IsTruncated>
    </ListBucketResult>
    """

    {items, trunc, token} = Orian.S3.XML.list_objects(xml)
    assert trunc == false and token == nil
    assert hd(items).key == "a/f.txt"
    assert hd(items).size == 12
  end

  test "local glob cp and sync" do
    root = Path.join(System.tmp_dir!(), "orian-#{System.unique_integer([:positive])}")
    src = Path.join(root, "src")
    dst = Path.join(root, "dst")
    File.mkdir_p!(src)
    File.write!(Path.join(src, "a.txt"), "hello")
    File.write!(Path.join(src, "b.txt"), "world")

    assert {:ok, %{ok: 2, error: 0}} = Orian.cp(Path.join(src, "*"), dst <> "/")
    assert File.read!(Path.join(dst, "a.txt")) == "hello"
    assert {:ok, %{ok: 0, error: 0}} = Orian.sync(src, dst)
    File.write!(Path.join(src, "c.txt"), "new")
    assert {:ok, %{ok: 1, error: 0}} = Orian.sync(src, dst)
    assert File.read!(Path.join(dst, "c.txt")) == "new"
  after
    # tmp cleaned by OS
    :ok
  end

  test "CLI help" do
    assert :ok = Orian.CLI.main(["--help"], halt: false)
    assert :ok = Orian.CLI.main(["version"], halt: false)
  end

  test "Rust transfer engine is loaded" do
    assert Orian.Engine.loaded?()
    assert {:ok, 0, 0} = Orian.Rs.bulk([], 8)
  end
end
