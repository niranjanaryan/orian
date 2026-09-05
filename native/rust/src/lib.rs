use rustler::{Binary, Env, NewBinary};

#[rustler::nif(schedule = "DirtyCpu")]
fn blake3<'a>(env: Env<'a>, data: Binary<'a>) -> Binary<'a> {
    let hash = blake3::hash(data.as_slice());
    let mut out = NewBinary::new(env, 32);
    out.copy_from_slice(hash.as_bytes());
    out.into()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn xxh3(data: Binary) -> u64 {
    xxhash_rust::xxh3::xxh3_64(data.as_slice())
}

rustler::init!("Elixir.Orian.Rs");
