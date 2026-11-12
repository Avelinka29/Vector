import Foundation
import Testing
@testable import DocumentVerificationCore

struct IdentityTests {
    let evaluator = DocumentVerificationEvaluator()

    func expected(first: String = "Анна", last: String = "Иванова", number: String = "", birth: Date? = nil) -> ExpectedDocumentData {
        ExpectedDocumentData(firstName: first, lastName: last, patronymic: "", firstNameLatin: nil,
                             lastNameLatin: nil, patronymicLatin: nil, birthDate: birth, passportNumber: number)
    }

    func check(_ text: String, kind: DocumentKind = .passport, person: ExpectedDocumentData? = nil,
               faces: Int = 1, width: Int = 1200) -> DocumentVerification {
        evaluator.evaluate(kind: kind, recognizedText: text, averageOCRConfidence: 0.99,
                           faceCount: faces, pixelWidth: width, pixelHeight: 1600,
                           expected: person ?? expected())
    }

    @Test(arguments: [DocumentKind.passport, .certificate, .examCertificate])
    func matchingAndDifferentNames(kind: DocumentKind) {
        let heading = "PASSPORT АТТЕСТАТ СЕРТИФИКАТ"
        #expect(check(heading + " ANNA IVANOVA", kind: kind).status == .likelyMatches)
        #expect(check(heading + " MARIA IVANOVA", kind: kind).status == .needsReview)
        #expect(check(heading + " ANNA PETROVA", kind: kind).status == .needsReview)
        #expect(check(heading + " ЖАННА ИВАНОВА", kind: kind).status == .needsReview)
        #expect(check(heading + " ANNA IVANOVA", kind: kind, person: expected(first: "")).status == .needsReview)
    }

    @Test func machineReadableNamesAndTransliteration() {
        #expect(check("PASSPORT P<BLRIVANOVA<<ANNA<<<<").status == .likelyMatches)
        #expect(check("PASSPORT YULIYA MAKSIMCHYK", person: expected(first: "Юлия", last: "Максимчык")).status == .likelyMatches)
    }

    @Test func missingEvidenceCannotPass() {
        #expect(check("ANNA IVANOVA").status == .needsReview)
        #expect(check("PASSPORT ANNA IVANOVA", faces: 0).status == .needsReview)
        #expect(check("PASSPORT ANNA IVANOVA", width: 300).status == .needsReview)
        #expect(check("PASSPORT ANNA IVANOVA", person: expected(number: "AB1234567")).status == .needsReview)
    }

    @Test func numericBirthDateAndPassportNumber() throws {
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2005, month: 8, day: 29)))
        let person = expected(number: "AB1234567", birth: date)
        #expect(check("PASSPORT ANNA IVANOVA AB1234567 29 08 2005", person: person).status == .likelyMatches)
        #expect(check("PASSPORT ANNA IVANOVA AB1234567 30 08 2005", person: person).status == .needsReview)
    }
}
