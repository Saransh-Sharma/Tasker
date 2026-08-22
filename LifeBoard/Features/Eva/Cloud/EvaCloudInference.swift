import Foundation

private struct EvaCloudStreamWireEvent: Decodable {
    let type: String
    let requestId: UUID
    let sequence: Int
    let credits: EvaCreditState?
    let quota: EvaQuotaState?
    let delta: String?
    let value: EvaJSONValue?
    let inputTokens: Int?
    let cachedInputTokens: Int?
    let cacheWriteTokens: Int?
    let outputTokens: Int?
    let reasoningTokens: Int?
    let speechTicket: String?
    let speechSource: String?
    let error: EvaErrorEnvelope?
}

extension EvaCloudTransport {
    func inference(_ request: EvaInferenceRequest) async throws -> AsyncThrowingStream<EvaStreamEvent, Error> {
        let body = try JSONEncoder.evaCloud.encode(request)
        let urlRequest = try await makeRequest(path: "/v1/eva/responses", method: "POST", body: body, authenticated: true, attested: true)
        let (bytes, response) = try await inferenceSession.bytes(for: urlRequest)
        try validate(response: response, errorData: nil)

        let (stream, continuation) = AsyncThrowingStream.makeStream(of: EvaStreamEvent.self)
        let task = Task {
            var expectedSequence = 0
            do {
                for try await line in bytes.lines {
                    guard line.hasPrefix("data: ") else { continue }
                    let payload = String(line.dropFirst(6))
                    guard let data = payload.data(using: .utf8) else { throw EvaProviderError.invalidResponse }
                    let wire = try JSONDecoder.evaCloud.decode(EvaCloudStreamWireEvent.self, from: data)
                    guard wire.sequence == expectedSequence else { throw EvaProviderError.invalidResponse }
                    expectedSequence += 1
                    continuation.yield(try Self.event(from: wire))
                }
                continuation.finish()
            } catch is CancellationError {
                continuation.finish(throwing: CancellationError())
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func speech(requestId: UUID, ticket: String, text: String, allowPaidRegeneration: Bool) async throws -> AsyncThrowingStream<Data, Error> {
        struct Body: Encodable {
            let requestId: UUID
            let speechTicket: String
            let text: String
            let allowPaidRegeneration: Bool
        }
        let body = try JSONEncoder.evaCloud.encode(Body(
            requestId: requestId,
            speechTicket: ticket,
            text: text,
            allowPaidRegeneration: allowPaidRegeneration
        ))
        let request = try await makeRequest(path: "/v1/eva/speech", method: "POST", body: body, authenticated: true, attested: true)
        return EvaSpeechDataStream.make(request: request)
    }

    fileprivate static func event(from wire: EvaCloudStreamWireEvent) throws -> EvaStreamEvent {
        switch wire.type {
        case "response.accepted": .accepted(requestId: wire.requestId, sequence: wire.sequence, quota: wire.quota, credits: wire.credits)
        case "response.text.delta":
            if let delta = wire.delta { .textDelta(requestId: wire.requestId, sequence: wire.sequence, delta: delta) }
            else { throw EvaProviderError.invalidResponse }
        case "response.structured":
            if let value = wire.value { .structured(requestId: wire.requestId, sequence: wire.sequence, value: value) }
            else { throw EvaProviderError.invalidResponse }
        case "response.usage": .usage(
            requestId: wire.requestId,
            sequence: wire.sequence,
            usage: EvaUsage(
                inputTokens: wire.inputTokens ?? 0,
                cachedInputTokens: wire.cachedInputTokens ?? 0,
                cacheWriteTokens: wire.cacheWriteTokens ?? 0,
                outputTokens: wire.outputTokens ?? 0,
                reasoningTokens: wire.reasoningTokens ?? 0
            )
        )
        case "response.completed": .completed(
            requestId: wire.requestId,
            sequence: wire.sequence,
            speechTicket: wire.speechTicket,
            speechSource: wire.speechSource,
            quota: wire.quota,
            credits: wire.credits
        )
        case "response.failed":
            if let error = wire.error { .failed(requestId: wire.requestId, sequence: wire.sequence, error: error) }
            else { throw EvaProviderError.invalidResponse }
        default: throw EvaProviderError.invalidResponse
        }
    }
}

private final class EvaSpeechDataStream: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var task: URLSessionDataTask?
    private var statusCode = 0
    private var errorData = Data()

    static func make(request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        let delegate = EvaSpeechDataStream()
        return AsyncThrowingStream { continuation in
            delegate.continuation = continuation
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            delegate.task = task
            continuation.onTermination = { _ in task.cancel() }
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if 200..<300 ~= statusCode { continuation?.yield(data) }
        else { errorData.append(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.finishTasksAndInvalidate() }
        if let error { continuation?.finish(throwing: error) }
        else if !(200..<300 ~= statusCode) {
            if let envelope = try? JSONDecoder.evaCloud.decode(EvaErrorEnvelope.self, from: errorData) {
                continuation?.finish(throwing: envelope)
            } else {
                continuation?.finish(throwing: EvaProviderError.unavailable("Spoken output returned HTTP \(statusCode)."))
            }
        } else { continuation?.finish() }
        continuation = nil
        self.task = nil
    }
}
