import SwiftUI

struct SnakeCell: Equatable { var x: Int; var y: Int }
struct SnakeGame {
    static let size = 18
    var body = [SnakeCell(x: 8, y: 9), SnakeCell(x: 7, y: 9), SnakeCell(x: 6, y: 9)]
    var direction = SnakeCell(x: 1, y: 0)
    var nextDirection = SnakeCell(x: 1, y: 0)
    var food = SnakeCell(x: 12, y: 9)
    var score = 0
    var ended = false
    var won = false
    var turned = false
    mutating func turn(_ value: SnakeCell) {
        guard !turned, value.x != -direction.x || value.y != -direction.y else { return }
        nextDirection = value; turned = true
    }
    mutating func step() {
        guard !ended else { return }
        direction = nextDirection; turned = false
        let next = SnakeCell(x: body[0].x + direction.x, y: body[0].y + direction.y)
        let eating = next == food
        let occupied = eating ? body : Array(body.dropLast())
        guard next.x >= 0, next.y >= 0, next.x < Self.size, next.y < Self.size, !occupied.contains(next) else { ended = true; return }
        body.insert(next, at: 0)
        if eating {
            score += 1
            let available = (0..<Self.size).flatMap { y in (0..<Self.size).map { SnakeCell(x: $0, y: y) } }.filter { !body.contains($0) }
            if let cell = available.randomElement() { food = cell } else { ended = true; won = true }
        } else { body.removeLast() }
    }
}

struct SnakeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game = SnakeGame()
    @State private var playing = false
    @AppStorage("snakeBestScore") private var best = 0
    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack { Text("Score: \(game.score)"); Spacer(); Text("Best: \(best)") }.font(.headline)
                GeometryReader { geometry in
                    let cell = min(geometry.size.width, geometry.size.height) / CGFloat(SnakeGame.size)
                    Canvas { context, _ in
                        for (index, point) in game.body.enumerated() {
                            let rect = CGRect(x: CGFloat(point.x) * cell + 1, y: CGFloat(point.y) * cell + 1, width: cell - 2, height: cell - 2)
                            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(index == 0 ? .green : .green.opacity(0.65)))
                        }
                        let rect = CGRect(x: CGFloat(game.food.x) * cell + 2, y: CGFloat(game.food.y) * cell + 2, width: cell - 4, height: cell - 4)
                        context.fill(Path(ellipseIn: rect), with: .color(.orange))
                    }
                    .frame(width: cell * CGFloat(SnakeGame.size), height: cell * CGFloat(SnakeGame.size))
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .gesture(DragGesture(minimumDistance: 15).onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            game.turn(SnakeCell(x: value.translation.width > 0 ? 1 : -1, y: 0))
                        } else { game.turn(SnakeCell(x: 0, y: value.translation.height > 0 ? 1 : -1)) }
                    })
                }.aspectRatio(1, contentMode: .fit)
                Text(game.ended ? (game.won ? "You won!" : "Game over") : "Swipe or use the arrows").foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    arrow("arrow.up", x: 0, y: -1)
                    HStack(spacing: 30) { arrow("arrow.left", x: -1, y: 0); arrow("arrow.down", x: 0, y: 1); arrow("arrow.right", x: 1, y: 0) }
                }
                Button(game.ended ? "Play Again" : (playing ? "Pause" : "Play")) {
                    if game.ended { game = SnakeGame() }
                    playing.toggle()
                }.buttonStyle(.borderedProminent)
            }.padding()
            .navigationTitle("Snake").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onReceive(timer) { _ in
                guard playing else { return }
                game.step(); best = max(best, game.score)
                if game.ended { playing = false }
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { playing = false } }
            .onDisappear { playing = false }
        }
    }
    private func arrow(_ symbol: String, x: Int, y: Int) -> some View {
        Button { game.turn(SnakeCell(x: x, y: y)) } label: { Image(systemName: symbol).frame(width: 44, height: 36) }.buttonStyle(.bordered)
    }
}
