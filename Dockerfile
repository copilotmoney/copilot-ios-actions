FROM swift:5.6.1 AS builder
WORKDIR /swift/code
COPY . ./
RUN swift build -c release

FROM swift:5.6.1-slim
WORKDIR /swift/app
COPY --from=builder /swift/code/.build/release/copilot-action ./
ENTRYPOINT ["/swift/app/copilot-action"]