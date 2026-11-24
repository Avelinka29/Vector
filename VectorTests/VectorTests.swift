import Foundation
import Testing

struct VectorTests {
    @Test(arguments: [
        "https://example.org/building.jpg",
        "http://localhost:8002/image.png"
    ])
    func catalogImageURLAcceptsWebSchemes(value: String) throws {
        let url = try #require(URL(string: value))

        #expect(["https", "http"].contains(url.scheme))
        #expect(url.host != nil)
    }

    @Test func catalogImageURLRejectsLocalFile() throws {
        let url = try #require(URL(string: "file:///tmp/building.jpg"))

        #expect(!["https", "http"].contains(url.scheme))
    }
}
