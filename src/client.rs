use getopts::Options;
use std::env;

use bim_core::clients::{Client, HTTPClient, SpeedtestNetTcpClient};
use bim_core::utils::justify_name;

fn print_usage(program: &str, opts: Options) {
    let brief = format!("Usage: {} DOWNLOAD_URL UPLOAD_URL [options]", program);
    print!("{}", opts.usage(&brief));
}

fn get_client(
    client_name: &str,
    download_url: String,
    upload_url: String,
    ipv6: bool,
    multi_thread: bool,
) -> Option<Box<dyn Client>> {
    match client_name {
        "http" => Some(Box::new(
            HTTPClient::build(download_url, upload_url, ipv6, multi_thread).unwrap(),
        )),
        "tcp" => Some(Box::new(
            SpeedtestNetTcpClient::build(upload_url, ipv6, multi_thread).unwrap(),
        )),
        _ => None,
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let program = args[0].clone();

    let mut opts = Options::new();
    opts.optopt("c", "client", "set test client", "NAME");
    opts.optflag("6", "ipv6", "enable ipv6");
    opts.optflag("m", "multi", "enable multi thread");
    opts.optflag("n", "name", "print justified name");
    opts.optflag("h", "help", "print this help menu");
    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(f) => {
            println!("{}\n", f.to_string());
            print_usage(&program, opts);
            return;
        }
    };

    if matches.opt_present("h") {
        print_usage(&program, opts);
        return;
    }

    let (dl, ul) = if !matches.free.is_empty() {
        (matches.free.get(0), matches.free.get(1))
    } else {
        print_usage(&program, opts);
        return;
    };

    if matches.opt_present("n") {
        if let Some(name) = dl {
            print!("{}", justify_name(name, 12, true));
        } else {
            print_usage(&program, opts);
        }
        return;
    }

    if ul.is_none() {
        print_usage(&program, opts);
        return;
    }

    let download_url = dl.unwrap().clone();
    let upload_url = ul.unwrap().clone();
    let ipv6 = matches.opt_present("6");
    let multi = matches.opt_present("m");

    #[cfg(debug_assertions)]
    env_logger::init();

    let client_name = matches.opt_str("c").unwrap_or("http".to_string());
    if let Some(mut client) = get_client(&client_name, download_url, upload_url, ipv6, multi) {
        let _ = (*client).run();
        let r = client.result();
        println!("{}", r.text());
    } else {
        println!("{client_name} client not found or invalid params.")
    }
}
