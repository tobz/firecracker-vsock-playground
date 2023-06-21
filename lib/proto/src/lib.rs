mod proto {
    tonic::include_proto!("processor");
}

pub mod client {
    pub use super::proto::processor_client::*;
}

pub mod server {
    pub use super::proto::processor_server::*;
}

pub mod messages {
    pub use super::proto::{ExecuteReply, ExecuteRequest};
}
