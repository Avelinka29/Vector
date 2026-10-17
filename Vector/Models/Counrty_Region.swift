import Foundation

struct Country: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let regions: [Region]
}

struct Region: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let cities: [City]
}

struct City: Identifiable, Codable, Equatable {
    let id: String
    let name: String
}

enum GeographyCatalog {
    static let countries: [Country] = [
        Country(
            id: "BY",
            name: "Беларусь",
            regions: [
                Region(id: "BY-HM", name: "Минск", cities: [
                    City(id: "minsk", name: "Минск")
                ]),
                Region(id: "BY-BR", name: "Брестская область", cities: [
                    City(id: "brest", name: "Брест"),
                    City(id: "baranovichi", name: "Барановичи"),
                    City(id: "pinsk", name: "Пинск")
                ]),
                Region(id: "BY-HO", name: "Гомельская область", cities: [
                    City(id: "gomel", name: "Гомель"),
                    City(id: "mozyr", name: "Мозырь")
                ]),
                Region(id: "BY-HR", name: "Гродненская область", cities: [
                    City(id: "grodno", name: "Гродно"),
                    City(id: "lida", name: "Лида")
                ]),
                Region(id: "BY-MA", name: "Могилёвская область", cities: [
                    City(id: "mogilev", name: "Могилёв"),
                    City(id: "bobruisk", name: "Бобруйск")
                ]),
                Region(id: "BY-MI", name: "Минская область", cities: [
                    City(id: "borisov", name: "Борисов"),
                    City(id: "molodechno", name: "Молодечно"),
                    City(id: "soligorsk", name: "Солигорск")
                ]),
                Region(id: "BY-VI", name: "Витебская область", cities: [
                    City(id: "vitebsk", name: "Витебск"),
                    City(id: "polotsk", name: "Полоцк"),
                    City(id: "orsha", name: "Орша")
                ])
            ]
        ),
        Country(id: "RU", name: "Россия", regions: []),
        Country(id: "PL", name: "Польша", regions: []),
        Country(id: "LT", name: "Литва", regions: []),
        Country(id: "LV", name: "Латвия", regions: []),
        Country(id: "OTHER", name: "Другая страна", regions: [])
    ]

    static func country(id: String) -> Country? {
        countries.first { $0.id == id }
    }

    static func region(id: String, countryID: String) -> Region? {
        country(id: countryID)?.regions.first { $0.id == id }
    }

    static func countryName(id: String) -> String {
        country(id: id)?.name ?? ""
    }

    static func regionName(id: String, countryID: String) -> String {
        region(id: id, countryID: countryID)?.name ?? ""
    }

    static func cityName(id: String, regionID: String, countryID: String) -> String {
        region(id: regionID, countryID: countryID)?.cities.first { $0.id == id }?.name ?? ""
    }
}
