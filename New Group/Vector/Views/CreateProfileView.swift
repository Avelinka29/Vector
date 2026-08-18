//
//  CreateProfileView.swift
//  Vector
//
//  Created by Avelina Maksimchik on 29.08.2026.
//

import SwiftUI

struct CreateProfileView: View {
    
    @State private var currentStep = 1
    let totalSteps = 10
    
    
    //firstStep
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var patronymic = ""
    @State private var birthdate = ""
    
    
    //secondStep
    @State private var email = ""
    @State private var phone = ""
    @State private var phone_rez = ""
    
    //thirdStep
    @State private var serya_num = ""
    @State private var ident_num = ""
    @State private var date_of_get = ""
    @State private var who_give = ""
    
    //forthStep
    @State private var country = ""
    @State private var region = ""
    @State private var city = ""
    @State private var street_home_numFlat = ""
    
    //fivethStep
    
    
    
    var body: some View {
        
        
        
        VStack(alignment: .leading, spacing: 18) {
            
            Spacer()
            
            Text("Шаг \(currentStep) из \(totalSteps)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.systemDarkBlue.opacity(0.5))
            
          
            
            Text (stepTitle)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.systemDarkBlue)
            
            
                
            HStack (spacing: 6) {
                ForEach (1...totalSteps, id: \.self) { step in
                    
                    Capsule()
                        .fill (
                            step <= currentStep
                            ? Color.systemBlue01
                            : Color.systemGrey1.opacity(0.25)
                        )
                        .frame(height: 5)
                }
            }
            
            Text(stepSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.systemDarkBlue.opacity(0.5))
            
            
            stepContent
            
            
            
            
            Button {
                nextStep()
            } label: {
                HStack(spacing: 10) {
                    Text(currentStep == totalSteps ? "Завершить" : "Далее")
                    
                    if currentStep != totalSteps {
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.systemWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.systemBlue01)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            if currentStep > 1 {
                Button {
                    previosStep()
                } label: {
                    Text("Назад")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.systemBlue01)
                        .frame(maxWidth: .infinity)
                    
                }
            }
            
            Spacer()
            
            
        }.padding(.horizontal, 24)
            
        
    }
    
    private func nextStep () {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }
    private func previosStep () {
        if currentStep > 1 {
            currentStep -= 1
        }
    }
    
    
    private var stepTitle: String {
        
        switch currentStep {
            
        case 1:
            return "Личные данные"
            
        case 2:
            return "Контактная информация"
            
        case 3:
            return "Паспортные данные"
            
        case 4:
            return "Адрес проживания"
            
        case 5:
            return "Образование"
            
        case 6:
            return "Учебное заведение"
            
        case 7:
            return "Документы"
            
        case 8:
            return "Результаты ЦЭ / ЦТ"
            
        case 9:
            return "Достижения"
            
        case 10:
            return "Достижения"
            
        default:
            return ""
        }
        
    }
    
    private var stepSubtitle: String {
        switch currentStep {
            
        case 1:
            return "Укажите основную информация о себе"
            
        case 2:
            return "Как с Вами можно связаться"
            
        case 3:
            return "Укажите данные паспорта"
            
        case 4:
            return "Укажите адрес вашей прописки"
            
        case 5:
            return "Укажите ваш текущий статус"
            
        case 6:
            return "Укажите вашу школу"
            
        case 7:
            return "Загрузите необходимые документы"
            
        case 8:
            return "Укажите ваши результаты"
            
        case 9:
            return "Расскажите о своих достижениях"
            
        case 10:
            return "Дополнительная информация"
            
            
        default:
            return ""
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        
        switch currentStep {
        case 1:
            VStack(spacing: 18) {
                VectorTextField2(placeholder: "Фамилия", icon: "person", text: $lastName)
                
                VectorTextField2(placeholder: "Имя", icon: "person",
                                 text: $firstName)
                
                VectorTextField2(placeholder: "Отчество", icon: "person",
                                 text: $patronymic)
                
                VectorTextField2(placeholder: "Дата рождения", icon: "birthday.cake",
                                 text: $birthdate)

            }
            
        case 2:
            VStack(spacing: 18) {
                VectorTextField2(placeholder: "Email", icon: "envelope", text: $email)
                
                VectorTextField2(placeholder: "Телефон", icon: "phone.fill",
                                 text: $phone)
                
                VectorTextField2(placeholder: "Резервный телефон (необязательно)", icon: "phone.fill",
                                 text: $phone_rez)
                
            }
            
        case 3:
            VStack(spacing: 18) {
                VectorTextField2(placeholder: "Серия и Номер", icon: nil, text: $serya_num)
                
                VectorTextField2(placeholder: "Идентификационный номер", icon: nil,
                                 text: $ident_num)
                
                VectorTextField2(placeholder: "Дата выдачи", icon: nil, text: $date_of_get)
                
                VectorTextField2(placeholder: "Кем выдан", icon: nil, text: $who_give)
                
                
            }
            
        case 4:
            VStack(spacing: 18) {
                
                ZStack {
                    VectorCountryPicker(placeholder: "Выбери страну", countries: countries, selectedCountry: $country)
                    
                    
                }.zIndex(100)
                
                
                VectorTextField2(placeholder: "Область", icon: nil,
                                 text: $region)
                
                VectorTextField2(placeholder: "Город", icon: nil, text: $city)
                
                VectorTextField2(placeholder: "Улица, дом, квартира", icon: nil, text: $street_home_numFlat)
    
            }
            
        
            
 
            

            
            
            
            
        default:
            VStack(spacing: 14) {
                VectorTextField2(placeholder: "Фамилия", icon: "person", text: $firstName)
                
                
            }
        }
        
        
    }
    
    private let countries = [
            "Беларусь",
            "Россия",
            "Украина",
            "Польша",
            "Литва",
            "Латвия",
            "Германия",
            "Франция",
            "ОАЭ",
            "Китай",
            "Сингапур",
            "Другое"
    ]
        
    
    
}

#Preview {
    CreateProfileView()
}
