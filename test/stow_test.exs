defmodule StowTest do
  use ExUnit.Case, async: false

  test "Zig NIF blake3 and xxh3" do
    assert Stow.nif_loaded?()
    h = Stow.blake3("hello")
    assert byte_size(h) == 32
    assert Stow.blake3("hello") == h
    assert Stow.blake3("hello") != Stow.blake3("world")
    assert is_integer(Stow.xxh3("hello"))
    assert Stow.xxh3("hello") != Stow.xxh3("world")
    assert is_integer(Stow.hash64("hello"))
  end

  test "Rust NIF agrees with Zig on BLAKE3" do
    result =
      try do
        Stow.Rs.blake3("hello")
      rescue
        e -> {:rescued, e}
      end

    assert is_binary(result) and byte_size(result) == 32, inspect(result)
    assert result == Stow.blake3("hello")
    assert Stow.Rs.xxh3("hello") == Stow.xxh3("hello")
  end

  test "memory put/get and S5 CID round-trip" do
    data = "stow blob"
    {:ok, cid} = Stow.put(data)
    assert cid.algo == :blake3
    assert cid.hash == Stow.blake3(data)
    assert {:ok, ^data} = Stow.get(cid)
    encoded = Stow.CID.encode(cid)
    assert {:ok, decoded} = Stow.CID.decode(encoded)
    assert decoded.hash == cid.hash
    assert {:error, :not_found} = Stow.get(Stow.blake3("missing"))
  end

  test "backends map" do
    b = Stow.backends()
    assert b.zig_nif
    assert is_boolean(b.rust_nif)
  end
end
