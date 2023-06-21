use tokio::process::Command;
use tokio_vsock::VsockListener;
use tonic::{transport::Server, Request, Response, Status};

use proto::{
    server::{Processor, ProcessorServer},
    messages::{ExecuteRequest, ExecuteReply},
};

#[derive(Default)]
pub struct TokioBackedProcessor {}

#[tonic::async_trait]
impl Processor for TokioBackedProcessor {
    async fn execute(
        &self,
        request: Request<ExecuteRequest>,
    ) -> Result<Response<ExecuteReply>, Status> {
        println!("Got a request from {:?}", request.remote_addr());

        let request = request.into_inner();

        let output = Command::new("/bin/bash")
            .arg("-c")
            .arg(request.command)
            .output()
            .await?;

        let reply = ExecuteReply {
            status: output.status.code().unwrap_or(0),
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stdout).to_string(), 
        };
        Ok(Response::new(reply))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let vsock_listener = VsockListener::bind(3, 50051)?;

    println!("guest-runner: waiting for connections");

    Server::builder()
        .add_service(ProcessorServer::new(TokioBackedProcessor::default()))
        .serve_with_incoming(vsock_listener.incoming())
        .await?;

    Ok(())
}
