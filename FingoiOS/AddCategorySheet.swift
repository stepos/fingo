import SwiftUI

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedColor = Color.indigoColor
    @State private var selectedIcon = "tag.fill"
    
    let icons = ["tag.fill", "cart.fill", "house.fill", "car.fill", "gamecontroller.fill", "building.columns.fill", "dollarsign.circle.fill", "ellipsis.circle.fill", "airplane", "bus", "fuelpump.fill", "heart.fill", "medical.thermometer.fill", "gift.fill", "graduationcap.fill", "bag.fill"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        TextField("Název kategorie", text: $name)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Barva")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                        
                        ColorPicker("Vyberte barvu ikony", selection: $selectedColor)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        Text("Ikona")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? selectedColor : .gray)
                                    .frame(width: 48, height: 48)
                                    .background(selectedIcon == icon ? selectedColor.opacity(0.15) : Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                    
                    Button(action: saveCategory) {
                        Text("Uložit kategorii")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(name.isEmpty ? Color.gray : Color.indigoColor)
                            .cornerRadius(20)
                            .shadow(color: (name.isEmpty ? Color.clear : Color.indigoColor.opacity(0.4)), radius: 10, x: 0, y: 5)
                    }
                    .disabled(name.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(white: 0.96).ignoresSafeArea())
            .navigationTitle("Nová kategorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }
                }
            }
        }
    }
    
    private func saveCategory() {
        let hexColor = selectedColor.toHex() ?? "#6366f1"
        let newCategory = FingoCategory(
            name: name,
            color: hexColor,
            icon: selectedIcon
        )
        FingoDataManager.shared.database.categories.append(newCategory)
        FingoDataManager.shared.saveDatabase()
        dismiss()
    }
}

extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if uic.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let rgb = (Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255)
            return String(format: "#%06x", rgb)
        }
        return nil
    }
}
