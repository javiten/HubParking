import SwiftUI

struct DiceRollView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dice1 = 1
    @State private var dice2 = 1
    @State private var isRolling = false
    @State private var opacity = 1.0
    @State private var scale = 1.0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 50) {
                HStack(spacing: 40) {
                    DiceView(number: dice1, isRolling: isRolling)
                        .opacity(opacity)
                        .scaleEffect(scale)
                    DiceView(number: dice2, isRolling: isRolling)
                        .opacity(opacity)
                        .scaleEffect(scale)
                }
                .padding()
                
                Button(action: rollDice) {
                    Text("Roll Again")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(isRolling)
            }
            .navigationTitle("Roll the Dice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: rollDice)
    }
    
    private func rollDice() {
        isRolling = true
        
        // Fade out with slight bounce
        withAnimation(.easeInOut(duration: 0.3)) {
            opacity = 0.3
            scale = 0.9
        }
        
        // Intermediate random values
        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    dice1 = Int.random(in: 1...6)
                    dice2 = Int.random(in: 1...6)
                }
            }
        }
        
        // Final values with fade in and bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dice1 = Int.random(in: 1...6)
            dice2 = Int.random(in: 1...6)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                opacity = 1.0
                scale = 1.0
                isRolling = false
            }
        }
    }
}

struct DiceView: View {
    let number: Int
    let isRolling: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(width: 100, height: 100)
                .shadow(radius: 5)
            
            VStack(spacing: 8) {
                ForEach(0..<3) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3) { column in
                            Circle()
                                .fill(shouldShowDot(row: row, column: column) ? .black : .clear)
                                .frame(width: 16, height: 16)
                        }
                        .frame(height: 20)
                    }
                }
            }
        }
    }
    
    private func shouldShowDot(row: Int, column: Int) -> Bool {
        switch number {
        case 1:
            return row == 1 && column == 1
        case 2:
            return (row == 0 && column == 0) || (row == 2 && column == 2)
        case 3:
            return (row == 0 && column == 0) || (row == 1 && column == 1) || (row == 2 && column == 2)
        case 4:
            return (row == 0 && column == 0) || (row == 0 && column == 2) ||
                   (row == 2 && column == 0) || (row == 2 && column == 2)
        case 5:
            return (row == 0 && column == 0) || (row == 0 && column == 2) ||
                   (row == 1 && column == 1) ||
                   (row == 2 && column == 0) || (row == 2 && column == 2)
        case 6:
            return (row == 0 && column == 0) || (row == 0 && column == 2) ||
                   (row == 1 && column == 0) || (row == 1 && column == 2) ||
                   (row == 2 && column == 0) || (row == 2 && column == 2)
        default:
            return false
        }
    }
} 