FROM swift:5.6.1 AS builder
WORKDIR /swift/code
COPY . ./
RUN swift build -c release

WORKDIR /swift
RUN git clone https://github.com/apple/swift-format.git
RUN cd swift-format && git checkout e6b8c60 && swift build -c release

FROM swift:5.6.1-slim
WORKDIR /swift/app
COPY --from=builder /swift/code/.build/release/copilot-action /usr/local/bin
COPY --from=builder /swift/swift-format/.build/release/swift-format  /usr/local/bin
ENTRYPOINT ["/usr/local/bin/copilot-action"]
