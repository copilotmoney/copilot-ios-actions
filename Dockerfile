FROM swift:5.7.0 AS builder
WORKDIR /swift/code
COPY . ./
RUN swift build -c release

WORKDIR /swift
RUN git clone https://github.com/apple/swift-format.git
RUN cd swift-format && git checkout 47eaedd258b5c86e8d75b80fe99cdb02197665a6 && swift build -c release

FROM swift:5.7.0-slim
COPY --from=builder /swift/code/.build/release/copilot-action /usr/local/bin
COPY --from=builder /swift/swift-format/.build/release/swift-format  /usr/local/bin
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:git-core/ppa
RUN apt-get update
RUN apt-get install -y git

ENTRYPOINT ["/usr/local/bin/copilot-action"]
