import CoreNFC
import Foundation
import PamNative

public final class NfcModule: NSObject, NativeModule, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.pam.nfc")
    private var session: NFCNDEFReaderSession?
    private var pending: NFCNDEFMessage?
    private var events: [[String: Any]] = []
    public func invoke(method: String, payload: Data, completion: @escaping ModuleCompletion) { queue.async { do { let v = try WireMap.decode(payload); switch method {
    case "availability": try self.success(["availability": .integer(NFCNDEFReaderSession.readingAvailable ? 1 : 2)], completion)
    case "beginRead": self.pending = nil; try self.begin(try v.text("prompt")); try self.success(completion: completion)
    case "write": self.pending = try self.message(try v.text("recordsJson")); try self.begin(try v.text("prompt")); try self.success(completion: completion)
    case "cancel": self.session?.invalidate(); self.session = nil; self.pending = nil; self.event(3); try self.success(completion: completion)
    case "poll": let n = min(128, max(1, Int(try v.integer("limit")))); let rows = Array(self.events.prefix(n)); self.events.removeFirst(min(n, self.events.count)); let data = try JSONSerialization.data(withJSONObject: rows); try self.success(["json": .text(String(data: data, encoding: .utf8) ?? "[]")], completion)
    default: throw NfcError.invalid }
    } catch { self.failure(error.localizedDescription, completion) } } }
    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) { queue.async { if (error as? NFCReaderError)?.code != .readerSessionInvalidationErrorUserCanceled { self.event(4, message: error.localizedDescription) }; self.session = nil } }
    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) { queue.async { guard self.pending == nil else { return }; self.event(1, records: self.records(messages.flatMap(\.records))); session.invalidate(); self.session = nil } }
    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) { guard let tag = tags.first else { return }; session.connect(to: tag) { error in if let error { self.event(4, message: error.localizedDescription); session.invalidate(); return }; tag.queryNDEFStatus { status, capacity, error in if let error { self.event(4, message: error.localizedDescription); session.invalidate(); return }; guard let message = self.pending, status == .readWrite, message.length <= capacity else { self.event(4, message: "Tag is read-only or has insufficient capacity."); session.invalidate(); return }; tag.writeNDEF(message) { error in self.queue.async { if let error { self.event(4, message: error.localizedDescription) } else { self.pending = nil; self.event(2); session.alertMessage = "NFC tag updated." }; session.invalidate(); self.session = nil } } } } }
    private func begin(_ prompt: String) throws { guard NFCNDEFReaderSession.readingAvailable else { throw NfcError.unavailable }; session?.invalidate(); let s = NFCNDEFReaderSession(delegate: self, queue: queue, invalidateAfterFirstRead: pending == nil); s.alertMessage = prompt; session = s; s.begin() }
    private func message(_ json: String) throws -> NFCNDEFMessage { let rows = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]] ?? []; guard !rows.isEmpty, rows.count <= 128 else { throw NfcError.invalid }; return NFCNDEFMessage(records: try rows.map { guard let tnf = NFCTypeNameFormat(rawValue: UInt8($0["tnf"] as? Int ?? -1)), let type = Data(base64Encoded: $0["typeBase64"] as? String ?? ""), let id = Data(base64Encoded: $0["idBase64"] as? String ?? ""), let payload = Data(base64Encoded: $0["payloadBase64"] as? String ?? "") else { throw NfcError.invalid }; return NFCNDEFPayload(format: tnf, type: type, identifier: id, payload: payload) }) }
    private func records(_ rows: [NFCNDEFPayload]) -> String { let values = rows.map { ["tnf": Int($0.typeNameFormat.rawValue), "typeBase64": $0.type.base64EncodedString(), "idBase64": $0.identifier.base64EncodedString(), "payloadBase64": $0.payload.base64EncodedString()] as [String: Any] }; return String(data: (try? JSONSerialization.data(withJSONObject: values)) ?? Data("[]".utf8), encoding: .utf8) ?? "[]" }
    private func event(_ kind: Int, records: String = "[]", message: String = "") { if events.count >= 128 { events.removeFirst() }; events.append(["kind": kind, "recordsJson": records, "message": String(message.prefix(1024))]) }
    private func success(_ values: [String: WireValue] = [:], _ completion: ModuleCompletion) throws { completion(.success, try WireMap.encode(values)) }
    private func failure(_ message: String, _ completion: ModuleCompletion) { completion(.failure, Data(message.prefix(1024).utf8)) }
}
private enum NfcError: Error { case unavailable, invalid }
private extension Dictionary where Key == String, Value == WireValue { func text(_ key: String) throws -> String { guard case let .text(v)? = self[key] else { throw NfcError.invalid }; return v }; func integer(_ key: String) throws -> Int64 { guard case let .integer(v)? = self[key] else { throw NfcError.invalid }; return v } }
