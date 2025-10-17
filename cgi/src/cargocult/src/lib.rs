use std::env;
use std::io::{self, Write};

fn header() {
    // Proper CGI header: exactly one blank line between headers and body
    print!("Content-Type: text/plain\r\n\r\n");
    let _ = io::stdout().flush();
}

fn get_page() -> String {
    let q = env::var("QUERY_STRING").unwrap_or_default();
    for pair in q.split('&') {
        let mut it = pair.splitn(2, '=');
        if let (Some(k), Some(v)) = (it.next(), it.next()) {
            if k == "page" { return v.to_string(); }
        }
    }
    "1".to_string()
}

fn main() {
    header();
    let page = get_page();
    let body = match page.as_str() {
        "1" => "An Army of One: a lone WASM wakes, answers, vanishes—leaving only calm CPUs and happy ledgers.",
        "2" => "The Fly: edge-borne, it lands for a sip of bytes, lifts off before latency knows the name.",
        "3" => "Cargo Cult: no rites, no runes—just sockets; planes land where packets are expected.",
        "4" => "The Gunslinger: one shot, one header, one body; smoke clears, the 200 still stands.",
        _   => "404 page: try ?page=1..4",
    };
    println!("{body}");
}
