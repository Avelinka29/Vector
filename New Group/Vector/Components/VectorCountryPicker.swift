//
//  VectorCountryPicker.swift
//  Vector
//
//  Created by Avelina Maksimchik on 02.09.2026.
//

import SwiftUI

struct VectorCountryPicker: View {
    
    let placeholder: String
    let countries: [String]
    
    @Binding var selectedCountry: String
    
    @State private var isShowingList = false
    @State private var searchText = ""
    
    
    private var filteredCountries: [String] {
        
        if searchText.isEmpty {
            return countries
        }
        
        return countries.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    
    var body: some View {
        
        ZStack(alignment: .top) {
            
            // MARK: Main field
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingList.toggle()
                    
                    if !isShowingList {
                        searchText = ""
                    }
                }
            } label: {
                
                HStack(spacing: 12) {
                    
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundStyle(.systemBlue01)
                    
                    Text(
                        selectedCountry.isEmpty
                        ? placeholder
                        : selectedCountry
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        selectedCountry.isEmpty
                        ? .systemDarkBlue.opacity(0.4)
                        : .systemDarkBlue
                    )
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            .systemDarkBlue.opacity(0.5)
                        )
                        .rotationEffect(
                            .degrees(
                                isShowingList ? 180 : 0
                            )
                        )
                }
                .padding(.horizontal, 18)
                .frame(height: 60)
                .background(.systemWhite)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        isShowingList
                        ? .systemBlue01
                        : .systemGrey1,
                        lineWidth: 1
                    )
                }
            }
            .buttonStyle(.plain)
            
            
            // MARK: Dropdown
            
            if isShowingList {
                
                countryList
                    .offset(y: 66)
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .top)
                        )
                    )
            }
        }
        .zIndex(100)
    }
    
    
    // MARK: - Country List
    
    private var countryList: some View {
        
        VStack(spacing: 0) {
            
            // MARK: Search
            
            HStack(spacing: 10) {
                
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(
                        .systemDarkBlue.opacity(0.4)
                    )
                
                TextField(
                    "Поиск страны",
                    text: $searchText
                )
                .font(
                    .system(
                        size: 15,
                        weight: .medium
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    
                    Button {
                        searchText = ""
                    } label: {
                        
                        Image(
                            systemName: "xmark.circle.fill"
                        )
                        .foregroundStyle(
                            .systemDarkBlue.opacity(0.35)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            
            
            Divider()
                .padding(.horizontal, 16)
            
            
            // MARK: Countries
            
            ScrollView {
                
                LazyVStack(spacing: 0) {
                    
                    ForEach(
                        filteredCountries,
                        id: \.self
                    ) { country in
                        
                        Button {
                            selectCountry(country)
                        } label: {
                            
                            HStack(spacing: 12) {
                                
                                Text(
                                    countryFlag(
                                        for: country
                                    )
                                )
                                .font(
                                    .system(size: 22)
                                )
                                
                                Text(country)
                                    .font(
                                        .system(
                                            size: 15,
                                            weight: .medium
                                        )
                                    )
                                    .foregroundStyle(
                                        .systemDarkBlue
                                    )
                                
                                Spacer()
                                
                                if selectedCountry == country {
                                    
                                    Image(
                                        systemName: "checkmark"
                                    )
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .semibold
                                        )
                                    )
                                    .foregroundStyle(
                                        .systemBlue01
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                        
                        
                        if country != filteredCountries.last {
                            
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                    
                    
                    // MARK: Empty result
                    
                    if filteredCountries.isEmpty {
                        
                        VStack(spacing: 8) {
                            
                            Image(
                                systemName: "magnifyingglass"
                            )
                            .font(
                                .system(size: 24)
                            )
                            .foregroundStyle(
                                .systemDarkBlue.opacity(0.3)
                            )
                            
                            Text("Страна не найдена")
                                .font(
                                    .system(
                                        size: 14,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(
                                    .systemDarkBlue.opacity(0.5)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 25)
                    }
                }
            }
            .frame(height: 240)
        }
        .background(.systemWhite)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                .systemGrey1,
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.10),
            radius: 12,
            y: 6
        )
    }
    
    
    // MARK: - Select Country
    
    private func selectCountry(
        _ country: String
    ) {
        
        selectedCountry = country
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingList = false
            searchText = ""
        }
    }
    
    
    // MARK: - Flags
    
    private func countryFlag(
        for country: String
    ) -> String {
        
        switch country {
            
        case "Беларусь":
            return "🇧🇾"
            
        case "Россия":
            return "🇷🇺"
            
        case "Украина":
            return "🇺🇦"
            
        case "Польша":
            return "🇵🇱"
            
        case "Литва":
            return "🇱🇹"
            
        case "Латвия":
            return "🇱🇻"
            
        case "Эстония":
            return "🇪🇪"
            
        case "Германия":
            return "🇩🇪"
            
        case "Франция":
            return "🇫🇷"
            
        case "Италия":
            return "🇮🇹"
            
        case "Испания":
            return "🇪🇸"
            
        case "Великобритания":
            return "🇬🇧"
            
        case "США":
            return "🇺🇸"
            
        case "Канада":
            return "🇨🇦"
            
        case "ОАЭ":
            return "🇦🇪"
            
        case "Китай":
            return "🇨🇳"
            
        case "Сингапур":
            return "🇸🇬"
            
        case "Япония":
            return "🇯🇵"
            
        case "Южная Корея":
            return "🇰🇷"
            
        default:
            return "🌎"
        }
    }
}


#Preview {
    VectorCountryPicker(placeholder: "Беларусь", countries: ["Беларусь", "Россия"], selectedCountry: .constant("Беларусь"))
}
