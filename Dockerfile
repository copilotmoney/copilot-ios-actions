FROM swift:5.10.0 AS builder
WORKDIR /swift/code
COPY . ./
RUN swift build -c release

WORKDIR /swift
RUN git clone https://github.com/apple/swift-format.git
RUN cd swift-format && git checkout 7996ac678197d293f6c088a1e74bb778b4e10139 && swift build -c release

FROM swift:5.10.0-slim
COPY --from=builder /swift/code/.build/release/copilot-action /usr/local/bin
COPY --from=builder /swift/swift-format/.build/release/swift-format /usr/local/bin
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:git-core/ppa
RUN apt-get update
RUN apt-get install -y git

ENTRYPOINT ["/usr/local/bin/copilot-action"]
