use std::{io, time::Instant};

use tokio::{net::UnixStream, io::{AsyncWriteExt, BufReader, AsyncBufReadExt}};
use tonic::{Request, transport::{Endpoint, Uri}};

use proto::{
    client::ProcessorClient,
    messages::ExecuteRequest,
};
use tower::service_fn;

async fn build_guest_vsock_connection(_: Uri) -> io::Result<UnixStream> {
    // Connect to the host-side Unix socket and tell Firecracker to connect to port 50051.
    let path = std::env::var("VSOCK_PATH")
        .expect("`VSOCK_PATH` environment variable must be set to the VSOCK socket file path");
    let mut stream = UnixStream::connect(path).await?;
    stream.write_all(b"CONNECT 50051\n").await?;

    // Now read the response from Firecracker, which should be a string in the form of
    // "OK <number>\n". As long as we get that back, the connection has been established on the
    // guest side and we can now use it for communications.
    let mut buffered = BufReader::new(stream);

    let mut response = String::new();
    buffered.read_line(&mut response).await?;

    if response.starts_with("OK") {
        Ok(buffered.into_inner())
    } else {
        Err(io::Error::new(io::ErrorKind::Other, "failed to connect to guest VSOCK"))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let channel = Endpoint::try_from("http://[::]:50051")?
        .connect_with_connector(service_fn(build_guest_vsock_connection))
        .await?;
    let mut client = ProcessorClient::new(channel);

    let request = Request::new(ExecuteRequest {
        command: "echo \"hello world\"".into(),
    });

    let start = Instant::now();
    let response = client.execute(request).await?;
    let elapsed = start.elapsed();

    println!("(cold) guest responded in {:?}: {:?}", elapsed, response);

    let request = Request::new(ExecuteRequest {
        command: "echo \"hello (again) world\"".into(),
    });


    let start = Instant::now();
    let response = client.execute(request).await?;
    let elapsed = start.elapsed();

    println!("(warm) guest responded in {:?}: {:?}", elapsed, response);

    Ok(())
}
