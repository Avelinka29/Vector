//
//  LoginView.swift
//  Vector
//
//  Created by Avelina Maksimchik on 18.08.2026.
//

import SwiftUI

struct LoginView: View {
    
    @State private var selectedTab = 0
    @State private var userName: String = ""
    @State private var userEmail: String = ""
    @State private var userPassword: String = ""
    @State private var showHome = false
    @State private var createProfile = false
    
    var body: some View {
        NavigationStack {
            
            
            ScrollView {
                

                
                VStack(alignment: .leading, spacing: 18) {
                    
                    Spacer()
                    
                    // Заголовки
                    if selectedTab == 0 {
                        Text("С возвращением")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.systemDarkBlue)
                    } else {
                        Text("Добро пожаловать в Vector")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.systemDarkBlue)
                    }
                    
                    Text("Единая цифровая платформа поступления")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.systemDarkBlue.opacity(0.5))
                    
                    Spacer()
                    
                    // Переключатель Вход/Регистрация
                    VStack(spacing: 20) {
                        HStack {
                            Button {
                                selectedTab = 0
                            } label: {
                                Text("Вход")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedTab == 0 ? Color(.systemWhite) : Color(.systemGrey1))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTab == 0 ? Color(.systemBlue01) : Color.clear)
                                    .cornerRadius(15)
                            }
                            
                            Button {
                                selectedTab = 1
                            } label: {
                                Text("Регистрация")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedTab == 1 ? Color(.systemWhite) : Color(.systemGrey1))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedTab == 1 ? Color(.systemBlue01) : Color.clear)
                                    .cornerRadius(15)
                            }
                        }
                        .padding(6)
                        .background(.systemWhite)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 5)
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                    }
                    .padding(.bottom, 10)
                    
                    if selectedTab == 0 {
                        // Поля входа
                        VectorTextField(icon: "envelope",
                                      iconColor: .grey01,
                                      iconSize: 18,
                                      placeholder: "Email или телефон",
                                      borderColor: .grey01,
                                      backgroundColor: .white,
                                      isSecure: false,
                                      text: $userEmail)
                        
                        VectorTextField(icon: "lock",
                                      iconColor: .grey01,
                                      iconSize: 18,
                                      placeholder: "Пароль",
                                      borderColor: .grey01,
                                      backgroundColor: .white,
                                      isSecure: true,
                                      text: $userPassword)
                        
                        HStack {
                            Spacer()
                            Button {} label: {
                                Text("Забыли пароль?")
                                    .foregroundColor(.systemBlue01)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .padding(.top, 5)
                        }
                        
                        VectorButton(title: "Войти", icon: "arrow.forward", backgroundColor: .blue01, isInfinity: true) {
                            showHome = true
                        }
                        

                        
                        HStack {
                            Rectangle()
                                .fill(.systemGrey1.opacity(0.5))
                                .frame(width: .infinity, height: 1)
                            
                            Text("ИЛИ")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.systemGrey1)
                            
                            Rectangle()
                                .fill(.systemGrey1.opacity(0.5))
                                .frame(width: .infinity, height: 1)
                        }
                        
                        Button{}
                        label: {
                            HStack(spacing: 10){
                                Image("Google")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 20, height: 20)
                                    .padding(.leading, 20)
                                
                                Spacer()
                                
                                HStack {
                                    
                                    Text("Продолжить с Google")
                                        .foregroundColor(.systemDarkBlue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 280, alignment: .leading)
                                        
                                    
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(Color(.systemWhite))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(.systemGrey1.opacity(0.5), lineWidth: 1))
                            
                            
                            
                        } .padding(.bottom, 10)
                        
                        
                        Button{}
                        label: {
                            HStack(spacing: 10){
                                Image("Apple")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 20, height: 20)
                                    .padding(.leading, 20)
                                
                                Spacer()
                                
                                HStack {
                                    
                                    Text("Продолжить с Apple")
                                        .foregroundColor(.systemDarkBlue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 280, alignment: .leading)
                                        
                                    
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(Color(.systemWhite))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(.systemGrey1.opacity(0.5), lineWidth: 1))
                            
                            
                            
                        } .padding(.bottom, 10)
                        
                        
                        
                        HStack {
                            Spacer()
                            Text("Нет аккаунта?")
                                .foregroundColor(.systemGrey1)
                            Button {selectedTab = 1} label: {
                                Text("Зарегистрироваться")
                                    .foregroundColor(.systemBlue01)
                                    .font(.system(size: 16, weight: .semibold))
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 5)
                            }
                            
                            
                            

                            
                            Spacer()
                            
                            
                            
                        }
                        .padding(.top, 5)

                    } else {
                        // Поля регистрации
                        
                        VectorTextField(icon: "envelope",
                                      iconColor: .grey01,
                                      iconSize: 18,
                                      placeholder: "Email или телефон",
                                      borderColor: .grey01,
                                      backgroundColor: .white,
                                      isSecure: false,
                                      text: $userEmail)
                        
                        VectorTextField(icon: "lock",
                                      iconColor: .grey01,
                                      iconSize: 18,
                                      placeholder: "Пароль",
                                      borderColor: .grey01,
                                      backgroundColor: .white,
                                      isSecure: true,
                                      text: $userPassword)
                        
                        VectorButton(title: "Зарегистрироваться", icon: "arrow.forward", backgroundColor: .blue01, isInfinity: true) {
                            createProfile = true
                        }
                        
                        HStack {
                            Rectangle()
                                .fill(.systemGrey1.opacity(0.5))
                                .frame(width: .infinity, height: 1)
                            
                            Text("ИЛИ")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.systemGrey1)
                            
                            Rectangle()
                                .fill(.systemGrey1.opacity(0.5))
                                .frame(width: .infinity, height: 1)
                        }
                        
                        Button{}
                        label: {
                            HStack(spacing: 10){
                                Image("Google")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 20, height: 20)
                                    .padding(.leading, 20)
                                
                                Spacer()
                                
                                HStack {
                                    
                                    Text("Продолжить с Google")
                                        .foregroundColor(.systemDarkBlue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 280, alignment: .leading)
                                        
                                    
                                }
                            }
                            
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(Color(.systemWhite))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(.systemGrey1.opacity(0.5), lineWidth: 1))
                            
                            
                            
                            
                        }
                        .padding(.bottom, 10)
                        
                        
                        Button{}
                        label: {
                            HStack(spacing: 10){
                                Image("Apple")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 20, height: 20)
                                    .padding(.leading, 20)
                                
                                Spacer()
                                
                                HStack {
                                    
                                    Text("Продолжить с Apple")
                                        .foregroundColor(.systemDarkBlue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 280, alignment: .leading)
                                        
                                    
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background(Color(.systemWhite))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(.systemGrey1.opacity(0.5), lineWidth: 1))
                            
                            
                            
                        } .padding(.bottom, 10)
                        
                        
                        HStack {
                            Spacer()
                            Text("Уже с нами?")
                                .foregroundColor(.systemGrey1)
                            Button {selectedTab = 0} label: {
                                Text("Войти")
                                    .foregroundColor(.systemBlue01)
                                    .font(.system(size: 16, weight: .semibold))
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 5)
                                    
                            }
                            
                            
                            Spacer()
                        }
                        .padding(.top, 5)
                        

                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
                
            }.navigationDestination(isPresented: $createProfile){
                CreateProfileView()
                    .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $showHome) {
               MainTabView()
                    .navigationBarBackButtonHidden(true)
            }
            
        }
        
    }
}

#Preview {
    LoginView()
}
