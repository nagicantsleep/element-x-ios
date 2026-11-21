//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
struct SchedulingServiceTests {
    // MARK: - Record store CRUD
    
    @Test
    func recordStoreCRUD() {
        let store = ScheduledMessageStore.make()
        let record = ScheduledMessageRecord(delayId: "delay1",
                                            roomId: "!room:example.com",
                                            sendAt: 1000,
                                            content: ["body": "hello"],
                                            eventType: "m.room.message")
        
        store.save(record)
        #expect(store.records() == [record])
        #expect(store.records(roomID: "!room:example.com") == [record])
        #expect(store.records(roomID: "!other:example.com").isEmpty)
        
        store.remove(delayId: "delay1")
        #expect(store.records().isEmpty)
    }
    
    @Test
    func recordStoreSavesArePerRoomAndOrdered() {
        let store = ScheduledMessageStore.make()
        let roomA = ScheduledMessageRecord(delayId: "a2", roomId: "!a:example.com", sendAt: 200, content: [:], eventType: "m.room.message")
        let roomAFirst = ScheduledMessageRecord(delayId: "a1", roomId: "!a:example.com", sendAt: 100, content: [:], eventType: "m.room.message")
        let roomB = ScheduledMessageRecord(delayId: "b1", roomId: "!b:example.com", sendAt: 300, content: [:], eventType: "m.room.message")
        
        store.save(roomA)
        store.save(roomB)
        store.save(roomAFirst)
        
        #expect(store.records(roomID: "!a:example.com").map(\.delayId) == ["a1", "a2"])
        #expect(store.records().map(\.delayId) == ["a1", "a2", "b1"])
    }
    
    @Test
    func recordStoreReplaceSameDelayId() {
        let store = ScheduledMessageStore.make()
        let original = ScheduledMessageRecord(delayId: "a1", roomId: "!a:example.com", sendAt: 100, content: ["body": "old"], eventType: "m.room.message")
        let updated = ScheduledMessageRecord(delayId: "a1", roomId: "!a:example.com", sendAt: 100, content: ["body": "new"], eventType: "m.room.message")
        
        store.save(original)
        store.save(updated)
        
        #expect(store.records() == [updated])
    }
    
    // MARK: - Flag gating (GET /versions)
    
    @Test
    func isSupportedWhenVersionsReportFeature() async {
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/_matrix/client/versions")
            return .success(json: ["unstable_features": ["org.matrix.msc4140": true]])
        }
        
        #expect(await service.isSupported())
    }
    
    @Test
    func isUnsupportedWhenVersionsMissFeature() async {
        let service = SchedulingService(clientProxy: mockClientProxy(homeserver: "https://unsupported.example.com"),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { _ in .success(json: ["unstable_features": ["org.matrix.msc4140": false]]) }
        
        #expect(await !service.isSupported())
    }
    
    @Test
    func isUnsupportedOnNetworkFailure() async {
        let service = SchedulingService(clientProxy: mockClientProxy(homeserver: "https://failing.example.com"),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { _ in .failsWith(statusCode: 500) }
        
        #expect(await !service.isSupported())
    }
    
    // MARK: - Send/cancel path (HTTP mocked)
    
    @Test
    func schedulePutsDelayQueryParamAndStoresRecord() async throws {
        let store = ScheduledMessageStore.make()
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: store)
        let sendAt = Date().addingTimeInterval(60)
        
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "PUT")
            #expect(request.url?.path.contains("/rooms/!room:example.com/send/m.room.message/") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
            let delayQuery = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "org.matrix.msc4140.delay" }
            let delayString = try #require(delayQuery?.value)
            let delay = try #require(Double(delayString))
            #expect(delay >= 59000 && delay <= 60000)
            return .success(json: ["delay_id": "delay123"])
        }
        
        let record = try await service.schedule(roomID: "!room:example.com",
                                                eventType: "m.room.message",
                                                content: ["body": "hello"],
                                                sendAt: sendAt).get()
        
        #expect(record.delayId == "delay123")
        #expect(store.records(roomID: "!room:example.com").map(\.delayId) == ["delay123"])
    }
    
    @Test
    func sendNowPostsSendActionAndDropsRecord() async throws {
        let store = ScheduledMessageStore.make()
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: store)
        store.save(.init(delayId: "delay123",
                         roomId: "!room:example.com",
                         sendAt: 1000,
                         content: ["body": "hello"],
                         eventType: "m.room.message"))
        
        MockURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/unstable/org.matrix.msc4140/delayed_events/delay123")
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
            #expect(body["action"] == "send")
            return .success(json: [:])
        }
        
        try await service.sendNow(delayId: "delay123").get()
        #expect(store.records().isEmpty)
    }
    
    @Test
    func cancelPostsCancelActionAndDropsRecord() async throws {
        let store = ScheduledMessageStore.make()
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: store)
        store.save(.init(delayId: "delay123",
                         roomId: "!room:example.com",
                         sendAt: 1000,
                         content: ["body": "hello"],
                         eventType: "m.room.message"))
        
        MockURLProtocol.handler = { request in
            let body = try #require(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
            #expect(body["action"] == "cancel")
            return .success(json: [:])
        }
        
        try await service.cancel(delayId: "delay123").get()
        #expect(store.records().isEmpty)
    }
    
    @Test
    func failedUpdateKeepsRecordOnlyWhenRecordExists() async {
        let store = ScheduledMessageStore.make()
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: store)
        store.save(.init(delayId: "delay123",
                         roomId: "!room:example.com",
                         sendAt: 1000,
                         content: ["body": "hello"],
                         eventType: "m.room.message"))
        
        MockURLProtocol.handler = { _ in .failsWith(statusCode: 500) }
        
        // The failed cancel leaves the record in place.
        guard case .failure(.failure) = await service.cancel(delayId: "delay123") else {
            Issue.record("Expected a generic failure")
            return
        }
        #expect(store.records().map(\.delayId) == ["delay123"])
    }
    
    // MARK: - Error mapping
    
    @Test
    func unrecognisedEndpointsMapToUnsupported() async {
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { _ in .failsWith(statusCode: 404) }
        
        guard case .failure(.unsupported) = await service.cancel(delayId: "delay123") else {
            Issue.record("Expected unsupported")
            return
        }
        guard case .failure(.unsupported) = await service.delayedEvents() else {
            Issue.record("Expected unsupported")
            return
        }
    }
    
    @Test
    func unrecognisedErrcodeMapsToUnsupported() async {
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { _ in .failsWith(statusCode: 400, json: ["errcode": "M_UNRECOGNIZED"]) }
        
        guard case .failure(.unsupported) = await service.cancel(delayId: "delay123") else {
            Issue.record("Expected unsupported")
            return
        }
    }
    
    @Test
    func serverFailureMapsToGenericFailure() async {
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { _ in .failsWith(statusCode: 500) }
        
        guard case .failure(.failure) = await service.cancel(delayId: "delay123") else {
            Issue.record("Expected a generic failure")
            return
        }
    }
    
    @Test
    func scheduleWithoutDelayIdFails() async {
        let service = SchedulingService(clientProxy: mockClientProxy(),
                                        urlSession: .mock,
                                        recordStore: ScheduledMessageStore.make())
        
        MockURLProtocol.handler = { _ in .success(json: [:]) }
        
        guard case .failure(.failure) = await service.schedule(roomID: "!room:example.com",
                                                               eventType: "m.room.message",
                                                               content: ["body": "hello"],
                                                               sendAt: .now) else {
            Issue.record("Expected a generic failure")
            return
        }
    }
    
    // MARK: - Composer flag gating
    
    @Test
    func composerShowsSendLaterOnlyWhenFlagOn() async throws {
        let supportedService = SchedulingServiceMock()
        supportedService.isSupportedReturnValue = true
        let viewModel = ComposerToolbarViewModel.mock(schedulingService: supportedService)
        
        try await Task.sleep(for: .milliseconds(100))
        #expect(viewModel.state.isSchedulingSupported)
        
        let unsupportedService = SchedulingServiceMock()
        unsupportedService.isSupportedReturnValue = false
        let unsupportedViewModel = ComposerToolbarViewModel.mock(schedulingService: unsupportedService)
        
        try await Task.sleep(for: .milliseconds(100))
        #expect(!unsupportedViewModel.state.isSchedulingSupported)
    }
    
    // MARK: - SendLaterOption presets (web's sendAtFor semantics)
    
    @Test
    func sendLaterOptionPresets() throws {
        let now = Date(timeIntervalSince1970: 86400) // Midnight UTC on day 2.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        
        #expect(try #require(SendLaterOption.in5Minutes.sendAt(now: now, calendar: calendar)) == now.addingTimeInterval(5 * 60))
        #expect(try #require(SendLaterOption.in30Minutes.sendAt(now: now, calendar: calendar)) == now.addingTimeInterval(30 * 60))
        #expect(try #require(SendLaterOption.in1Hour.sendAt(now: now, calendar: calendar)) == now.addingTimeInterval(60 * 60))
        #expect(SendLaterOption.custom.sendAt(now: now, calendar: calendar) == nil)
        
        // Tomorrow morning is 9am the next day.
        let tomorrowMorning = try #require(SendLaterOption.tomorrowMorning.sendAt(now: now, calendar: calendar))
        #expect(calendar.isDate(tomorrowMorning, equalTo: now, toGranularity: .day) == false)
        #expect(calendar.component(.hour, from: tomorrowMorning) == 9)
    }
    
    // MARK: - Helpers
    
    private func mockClientProxy(homeserver: String = "https://matrix.example.com") -> ClientProxyMock {
        let mock = ClientProxyMock(.init())
        mock.homeserver = homeserver
        mock.accessTokenReturnValue = "token"
        return mock
    }
}

private nonisolated enum MockURLProtocol {
    enum Response {
        case success(json: [String: Any])
        case failsWith(statusCode: Int, json: [String: Any] = [:])
    }
    
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> Response)?
    
    static func makeResponse(for request: URLRequest) throws -> (Data, URLResponse) {
        struct HandlerError: Error { }
        
        guard let handler else {
            throw HandlerError()
        }
        
        let url = try #require(request.url)
        
        let statusCode: Int
        let json: [String: Any]
        switch try handler(request) {
        case .success(let body):
            statusCode = 200
            json = body
        case .failsWith(let code, let body):
            statusCode = code
            json = body
        }
        
        let data = try JSONSerialization.data(withJSONObject: json)
        guard let httpResponse = HTTPURLResponse(url: url,
                                                 statusCode: statusCode,
                                                 httpVersion: nil,
                                                 headerFields: nil) else {
            throw HandlerError()
        }
        return (data, httpResponse)
    }
}

/// An `URLProtocol` implementation that responds to requests through `MockURLProtocol.handler`.
private nonisolated class MockURLProtocolClass: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        do {
            let (data, urlResponse) = try MockURLProtocol.makeResponse(for: Self.materializedRequest(from: request))
            client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() { }
    
    /// URLSession hands the body over as a stream, materialise it so tests can inspect it.
    private static func materializedRequest(from request: URLRequest) -> URLRequest {
        var urlRequest = request
        if urlRequest.httpBody == nil, let bodyStream = urlRequest.httpBodyStream {
            urlRequest.httpBody = data(from: bodyStream)
        }
        return urlRequest
    }
    
    private static func data(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        
        let bufferSize = 4096
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

private extension URLSession {
    static var mock: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocolClass.self]
        return URLSession(configuration: configuration)
    }
}

private extension UserDefaults {
    /// A fresh in-memory store per call, avoiding cross-test pollution of `.standard`.
    static func volatile() -> UserDefaults {
        let suiteName = "scheduling-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        return defaults ?? .standard
    }
}

private extension ScheduledMessageStore {
    static func make(defaults: UserDefaults = .volatile()) -> ScheduledMessageStore {
        ScheduledMessageStore(defaults: defaults)
    }
}
