use futures_util::StreamExt;
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::{Client, Method};
use rustler::{Atom, NifResult};
use std::str::FromStr;
use std::sync::OnceLock;
use std::time::Duration;
use tokio::io::AsyncWriteExt;
use tokio::runtime::Runtime;
use tokio::sync::Semaphore;

static RT: OnceLock<Runtime> = OnceLock::new();
static CLIENT: OnceLock<Client> = OnceLock::new();

fn rt() -> &'static Runtime {
    RT.get_or_init(|| {
        let n = std::thread::available_parallelism()
            .map(|n| n.get() * 2)
            .unwrap_or(16);
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(n.max(8))
            .thread_name("orian")
            .enable_all()
            .build()
            .expect("orian tokio runtime")
    })
}

fn client() -> &'static Client {
    CLIENT.get_or_init(|| {
        Client::builder()
            .pool_max_idle_per_host(256)
            .pool_idle_timeout(Duration::from_secs(90))
            .tcp_nodelay(true)
            .connect_timeout(Duration::from_secs(10))
            .timeout(Duration::from_secs(300))
            .http1_only()
            .build()
            .expect("orian http client")
    })
}

fn headers_from(pairs: &[(String, String)]) -> Result<HeaderMap, String> {
    let mut map = HeaderMap::new();
    for (k, v) in pairs {
        let name = HeaderName::from_str(k).map_err(|e| e.to_string())?;
        let val = HeaderValue::from_str(v).map_err(|e| e.to_string())?;
        map.insert(name, val);
    }
    Ok(map)
}

async fn put_one(url: &str, path: &str, hdrs: &[(String, String)]) -> Result<(), String> {
    let meta = tokio::fs::metadata(path)
        .await
        .map_err(|e| format!("stat {path}: {e}"))?;
    let file = tokio::fs::File::open(path)
        .await
        .map_err(|e| format!("open {path}: {e}"))?;
    let stream = tokio_util::io::ReaderStream::with_capacity(file, 1024 * 1024);
    let resp = client()
        .request(Method::PUT, url)
        .headers(headers_from(hdrs)?)
        .header("content-length", meta.len())
        .body(reqwest::Body::wrap_stream(stream))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = resp.status();
    if status.is_success() {
        Ok(())
    } else {
        let body = resp.text().await.unwrap_or_default();
        Err(format!("put {status}: {body}"))
    }
}

async fn get_one(url: &str, path: &str, hdrs: &[(String, String)]) -> Result<(), String> {
    if let Some(parent) = std::path::Path::new(path).parent() {
        tokio::fs::create_dir_all(parent)
            .await
            .map_err(|e| e.to_string())?;
    }
    let resp = client()
        .request(Method::GET, url)
        .headers(headers_from(hdrs)?)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = resp.status();
    if !status.is_success() {
        let body = resp.text().await.unwrap_or_default();
        return Err(format!("get {status}: {body}"));
    }
    let mut file = tokio::fs::File::create(path)
        .await
        .map_err(|e| format!("create {path}: {e}"))?;
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| e.to_string())?;
        file.write_all(&chunk).await.map_err(|e| e.to_string())?;
    }
    file.flush().await.map_err(|e| e.to_string())?;
    Ok(())
}

async fn pipe_one(
    src_url: &str,
    src_hdrs: &[(String, String)],
    dst_url: &str,
    dst_hdrs: &[(String, String)],
) -> Result<(), String> {
    let resp = client()
        .request(Method::GET, src_url)
        .headers(headers_from(src_hdrs)?)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("pipe get {}", resp.status()));
    }
    let len = resp.content_length();
    let stream = resp.bytes_stream();
    let mut req = client()
        .request(Method::PUT, dst_url)
        .headers(headers_from(dst_hdrs)?);
    if let Some(n) = len {
        req = req.header("content-length", n);
    }
    let resp = req
        .body(reqwest::Body::wrap_stream(stream))
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if resp.status().is_success() {
        Ok(())
    } else {
        Err(format!("pipe put {}", resp.status()))
    }
}

pub fn bulk(
    jobs: Vec<(String, String, String, Vec<(String, String)>)>,
    concurrency: u32,
) -> (Atom, u32, u32) {
    let conc = concurrency.max(1) as usize;
    let (ok, err) = rt().block_on(async move {
        let sem = std::sync::Arc::new(Semaphore::new(conc));
        let mut set = tokio::task::JoinSet::new();
        for (op, url, path, hdrs) in jobs {
            let sem = sem.clone();
            set.spawn(async move {
                let _p = sem.acquire().await.expect("sem");
                match op.as_str() {
                    "put" => put_one(&url, &path, &hdrs).await,
                    "get" => get_one(&url, &path, &hdrs).await,
                    _ => Err(format!("bad op {op}")),
                }
            });
        }
        let mut ok = 0u32;
        let mut err = 0u32;
        while let Some(r) = set.join_next().await {
            match r {
                Ok(Ok(())) => ok += 1,
                _ => err += 1,
            }
        }
        (ok, err)
    });
    (rustler::types::atom::ok(), ok, err)
}

pub fn put_file(url: String, path: String, hdrs: Vec<(String, String)>) -> NifResult<Atom> {
    rt()
        .block_on(put_one(&url, &path, &hdrs))
        .map(|_| rustler::types::atom::ok())
        .map_err(|e| rustler::Error::Term(Box::new(e)))
}

pub fn get_file(url: String, path: String, hdrs: Vec<(String, String)>) -> NifResult<Atom> {
    rt()
        .block_on(get_one(&url, &path, &hdrs))
        .map(|_| rustler::types::atom::ok())
        .map_err(|e| rustler::Error::Term(Box::new(e)))
}

pub fn pipe(
    src_url: String,
    src_hdrs: Vec<(String, String)>,
    dst_url: String,
    dst_hdrs: Vec<(String, String)>,
) -> NifResult<Atom> {
    rt()
        .block_on(pipe_one(&src_url, &src_hdrs, &dst_url, &dst_hdrs))
        .map(|_| rustler::types::atom::ok())
        .map_err(|e| rustler::Error::Term(Box::new(e)))
}


