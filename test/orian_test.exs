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
    assert result == Orian.blake3("hello")
    assert Orian.Rs.xxh3("hello") == Orian.xxh3("hello")
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
end
