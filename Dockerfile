FROM swift:6.1.0 AS builder
WORKDIR /swift/code
COPY . ./
RUN swift build -c release

WORKDIR /swift
RUN git clone https://github.com/apple/swift-format.git
RUN cd swift-format && git checkout 65f9da9aad84adb7e2028eb32ca95164aa590e3b && swift build -c release

RUN git clone https://github.com/copilotmoney/appstoreconnect.git
RUN cd appstoreconnect && swift build -c release

FROM swift:6.1.0-slim
COPY --from=builder /swift/code/.build/release/copilot-action /usr/local/bin
COPY --from=builder /swift/swift-format/.build/release/swift-format /usr/local/bin
COPY --from=builder /swift/appstoreconnect/.build/release/appstoreconnect /usr/local/bin
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:git-core/ppa
RUN apt-get update
RUN apt-get install -y git

ENTRYPOINT ["/usr/local/bin/copilot-action"]
