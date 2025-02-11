use std::error::Error;
use std::net::{SocketAddr, ToSocketAddrs};
use std::sync::{Arc, Barrier, RwLock};
use std::thread;
use std::time::{Duration, Instant};

#[cfg(debug_assertions)]
use log::debug;

use url::Url;

use crate::clients::base::{make_connection, Client};
use crate::utils::SpeedTestResult;

use std::io::{Read, Write};
use std::net::TcpStream;

pub struct SpeedtestNetTcpClient {
    multi_thread: bool,

    address: SocketAddr,

    upload: f64,
    upload_status: String,
    download: f64,
    download_status: String,
    latency: f64,
    jitter: f64,
}

impl SpeedtestNetTcpClient {
    pub fn build(url: String, ipv6: bool, multi_thread: bool) -> Option<Self> {
        let url = match Url::parse(&url) {
            Ok(u) => u,
            Err(_) => return None,
        };

        let host = match url.host_str() {
            Some(h) => h,
            None => return None,
        };
        let port = match url.port_or_known_default() {
            Some(p) => p,
            None => return None,
        };

        let host_port = format!("{host}:{port}");
        let addresses = match host_port.to_socket_addrs() {
            Ok(addrs) => addrs,
            Err(_) => return None,
        };

        let mut address = None;
        for addr in addresses {
            if (addr.is_ipv6() && ipv6) || (addr.is_ipv4() && !ipv6) {
                address = Some(addr);
            }
        }

        let address = match address {
            Some(addr) => addr,
            None => return None,
        };

        #[cfg(debug_assertions)]
        debug!("IP address {address}");

        let r = String::from("取消");
        Some(Self {
            multi_thread,
            address,
            upload: 0.0,
            upload_status: r.clone(),
            download: 0.0,
            download_status: r.clone(),
            latency: 0.0,
            jitter: 0.0,
        })
    }

    fn run_load(&mut self, load: u8) -> Result<bool, Box<dyn Error>> {
        let threads = if self.multi_thread { 8 } else { 1 };
        let mut counters = vec![];

        let start = Arc::new(Barrier::new(threads + 1));
        let stop = Arc::new(RwLock::new(false));
        let end = Arc::new(Barrier::new(threads + 1));

        for _ in 0..threads {
            let a = self.address.clone();
            let ct = Arc::new(RwLock::new(0u128));
            counters.push(ct.clone());

            let s = start.clone();
            let f = stop.clone();
            let e = end.clone();

            thread::spawn(move || {
                let _ = match load {
                    0 => request_tcp_upload(a, ct, s, f, e),
                    _ => request_tcp_download(a, ct, s, f, e),
                };
            });
            thread::sleep(Duration::from_millis(250));
        }

        let mut last = 0;
        let mut last_time = 0;
        let mut time_passed = 0;
        let mut results = [0.0; 28];
        let mut index = 0;
        let mut wait = 6;

        start.wait();
        let now = Instant::now();
        while time_passed < 14_000_000 {
            thread::sleep(Duration::from_millis(500));
            time_passed = now.elapsed().as_micros();
            let time_used = time_passed - last_time;

            let current = {
                let mut count = 0;
                for ct in counters.iter() {
                    let num = ct.read().unwrap();
                    count += *num
                }
                count
            };

            if last == current {
                wait -= 1;
            }
            let speed = ((current - last) * 8) as f64 / time_used as f64;

            #[cfg(debug_assertions)]
            debug!("Transfered {current} bytes in {time_passed} us, speed {speed}");

            results[index] = speed;
            index += 1;
            last = current;
            last_time = time_passed;
        }

        {
            let mut f = stop.write().unwrap();
            *f = true;
        }
        end.wait();

        let mut all = 0.0;
        for i in index - 20..index {
            all += results[i];
        }
        let final_speed = all / 20.0;

        let status = if wait <= 0 {
            if last < 200 {
                "失败"
            } else {
                "断流"
            }
        } else {
            "正常"
        }
        .to_string();

        match load {
            0 => {
                self.upload = final_speed;
                self.upload_status = status;
            }
            _ => {
                self.download = final_speed;
                self.download_status = status;
            }
        }

        Ok(true)
    }
}

impl Client for SpeedtestNetTcpClient {
    fn ping(&mut self) -> bool {
        let mut count = 0;
        let mut pings = [0u128; 6];
        let mut ping_min = 10000000;

        while count < 6 {
            let ping = request_tcp_ping(&self.address);
            if ping > 0 {
                if ping < ping_min {
                    ping_min = ping
                }
                pings[count] = ping;
            }
            thread::sleep(Duration::from_millis(1000));
            count += 1;
        }

        if pings == [0, 0, 0, 0, 0, 0] {
            self.latency = 0.0;
            self.jitter = 0.0;
            return false;
        }

        let mut jitter_all = 0;
        for p in pings {
            if p > 0 {
                jitter_all += p - ping_min;
            }
        }

        self.latency = ping_min as f64 / 1_000.0;
        self.jitter = jitter_all as f64 / 5_000.0;

        #[cfg(debug_assertions)]
        debug!("Ping {} ms", self.latency);

        #[cfg(debug_assertions)]
        debug!("Jitter {} ms", self.jitter);

        true
    }

    fn download(&mut self) -> bool {
        match self.run_load(1) {
            Ok(_) => true,
            Err(_) => false,
        }
    }

    fn upload(&mut self) -> bool {
        match self.run_load(0) {
            Ok(_) => true,
            Err(_) => false,
        }
    }

    fn result(&self) -> SpeedTestResult {
        SpeedTestResult::build(
            self.upload,
            self.upload_status.clone(),
            self.download,
            self.download_status.clone(),
            self.latency,
            self.jitter,
        )
    }
}

fn request_tcp_ping(address: &SocketAddr) -> u128 {
    let now = Instant::now();
    let r = TcpStream::connect_timeout(&address, Duration::from_micros(1_000_000));
    let used = now.elapsed().as_micros();
    match r {
        Ok(_) => used,
        Err(_e) => {
            #[cfg(debug_assertions)]
            debug!("Ping {_e}");

            0
        }
    }
}

fn request_tcp_download(
    address: SocketAddr,
    counter: Arc<RwLock<u128>>,
    start: Arc<Barrier>,
    stop: Arc<RwLock<bool>>,
    end: Arc<Barrier>,
) {
    let data_size = 15 * 1024 * 1024 * 1024 as u128;
    let mut buffer = [0; 65536];

    let url = Url::parse("http://bench.im").unwrap();
    let mut stream = match make_connection(&address, &url) {
        Ok(s) => s,
        Err(_) => {
            start.wait();
            end.wait();
            return;
        }
    };

    start.wait();

    #[cfg(debug_assertions)]
    debug!("Download Start");

    let request = format!("DOWNLOAD {data_size}\n").into_bytes();
    match stream.write_all(&request) {
        Ok(_) => {
            if let Ok(size) = stream.read(&mut buffer) {
                #[cfg(debug_assertions)]
                debug!("Download Status: {size}");

                if size == 0 {
                    #[cfg(debug_assertions)]
                    debug!("Download Error: Start failed");

                    end.wait();
                    return;
                }

                let mut ct = counter.write().unwrap();
                *ct += size as u128;
            } else {
                end.wait();
                return;
            }
        }
        Err(_e) => {
            #[cfg(debug_assertions)]
            debug!("Download Error: {}", _e);

            end.wait();
            return;
        }
    }

    while !*(stop.read().unwrap()) {
        match stream.read(&mut buffer) {
            Ok(size) => {
                let mut ct = counter.write().unwrap();
                *ct += size as u128;
            }
            Err(_e) => {
                #[cfg(debug_assertions)]
                debug!("Download Error: {}", _e);

                end.wait();
                return;
            }
        }
    }
    end.wait();
}

fn request_tcp_upload(
    address: SocketAddr,
    counter: Arc<RwLock<u128>>,
    start: Arc<Barrier>,
    stop: Arc<RwLock<bool>>,
    end: Arc<Barrier>,
) {
    let data_size = 15 * 1024 * 1024 * 1024 as u128;
    let request_chunk = "0123456789AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz-="
        .repeat(1024)
        .into_bytes();

    let url = Url::parse("http://bench.im").unwrap();

    let mut stream = match make_connection(&address, &url) {
        Ok(s) => s,
        Err(_) => {
            start.wait();
            end.wait();
            return;
        }
    };

    start.wait();
    #[cfg(debug_assertions)]
    debug!("Upload Start");

    let request = format!("UPLOAD {data_size} 0\n").into_bytes();
    match stream.write_all(&request) {
        Ok(_) => {
            let mut ct = counter.write().unwrap();
            *ct += request.len() as u128;
        }
        Err(_e) => {
            #[cfg(debug_assertions)]
            debug!("Upload Error: {}", _e);

            end.wait();
            return;
        }
    }

    while !*(stop.read().unwrap()) {
        match stream.write(&request_chunk) {
            Ok(size) => {
                let mut ct = counter.write().unwrap();
                *ct += size as u128;
            }
            Err(_e) => {
                #[cfg(debug_assertions)]
                debug!("Upload Error: {}", _e);

                end.wait();
                return;
            }
        }
    }
    end.wait();
}
