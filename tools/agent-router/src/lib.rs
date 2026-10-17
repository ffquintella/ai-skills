pub mod config;
pub mod quota;
pub mod router;
pub mod rpc;

#[derive(Debug)]
pub struct Error {
    pub exit: i32,
    pub code: &'static str,
    pub message: String,
}

impl Error {
    pub fn invalid(message: impl Into<String>) -> Self {
        Self {
            exit: 2,
            code: "invalid_input",
            message: message.into(),
        }
    }
    pub fn adapter(message: impl Into<String>) -> Self {
        Self {
            exit: 5,
            code: "adapter_failure",
            message: message.into(),
        }
    }
}

pub type Result<T> = std::result::Result<T, Error>;
