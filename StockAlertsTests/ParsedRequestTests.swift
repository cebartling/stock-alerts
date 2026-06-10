#if DEBUG
import Testing
import Foundation
@testable import StockAlerts

struct ParsedRequestTests {

    @Test
    func completeGet_noBody_parses() {
        let req = ParsedRequest(Data("GET /state HTTP/1.1\r\nHost: localhost\r\n\r\n".utf8))
        #expect(req?.method == "GET")
        #expect(req?.path == "/state")
        #expect(req?.body.isEmpty == true)
    }

    @Test
    func missingHeaderTerminator_returnsNil() {
        // No blank line yet — headers not fully received.
        #expect(ParsedRequest(Data("GET /state HTTP/1.1\r\nHost: localhost\r\n".utf8)) == nil)
    }

    @Test
    func postBody_splitAcrossChunks_nilThenParsed() {
        let headers = "POST /watchlist HTTP/1.1\r\nContent-Length: 17\r\n\r\n"
        // Headers arrived but the 17-byte body has not — incomplete.
        #expect(ParsedRequest(Data(headers.utf8)) == nil)

        let full = headers + #"{"symbol":"MSFT"}"#
        let req = ParsedRequest(Data(full.utf8))
        #expect(req?.method == "POST")
        #expect(req?.path == "/watchlist")
        #expect(req.map { String(decoding: $0.body, as: UTF8.self) } == #"{"symbol":"MSFT"}"#)
    }

    @Test
    func contentLengthExceedsAvailable_returnsNil() {
        #expect(ParsedRequest(Data("POST /x HTTP/1.1\r\nContent-Length: 100\r\n\r\nshort".utf8)) == nil)
    }

    @Test
    func malformedRequestLine_returnsNil() {
        #expect(ParsedRequest(Data("GARBAGE\r\n\r\n".utf8)) == nil)
    }
}
#endif
