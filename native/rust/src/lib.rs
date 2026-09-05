mod engine;

use rustler::{Atom, Binary, Env, NewBinary, NifResult};

#[rustler::nif(schedule = "DirtyIo")]
fn bulk(
    jobs: Vec<(String, String, String, Vec<(String, String)>)>,
    concurrency: u32,
) -> (Atom, u32, u32) {
    engine::bulk(jobs, concurrency)
}

#[rustler::nif(schedule = "DirtyIo")]
fn put_file(url: String, path: String, hdrs: Vec<(String, String)>) -> NifResult<Atom> {
    engine::put_file(url, path, hdrs)
}

#[rustler::nif(schedule = "DirtyIo")]
fn get_file(url: String, path: String, hdrs: Vec<(String, String)>) -> NifResult<Atom> {
    engine::get_file(url, path, hdrs)
}

#[rustler::nif(schedule = "DirtyIo")]
fn pipe(
    src_url: String,
    src_hdrs: Vec<(String, String)>,
    dst_url: String,
    dst_hdrs: Vec<(String, String)>,
) -> NifResult<Atom> {
    engine::pipe(src_url, src_hdrs, dst_url, dst_hdrs)
}

#[rustler::nif]
fn engine_loaded() -> bool {
    true
}

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
