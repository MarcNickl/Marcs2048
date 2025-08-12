import SwiftUI

struct GameView: View {
    @StateObject private var model = GameModel()
    @GestureState private var dragOffset: CGSize = .zero

    private let spacing: CGFloat = 10
    private let gridSize: Int = GameModel.gridSize

    private func tileColor(_ value: Int) -> Color {
        switch value {
        case 0: return Color(hex: 0xCDC1B4)
        case 2: return Color(hex: 0xEEE4DA)
        case 4: return Color(hex: 0xEDE0C8)
        case 8: return Color(hex: 0xF2B179)
        case 16: return Color(hex: 0xF59563)
        case 32: return Color(hex: 0xF67C5F)
        case 64: return Color(hex: 0xF65E3B)
        case 128: return Color(hex: 0xEDCF72)
        case 256: return Color(hex: 0xEDCC61)
        case 512: return Color(hex: 0xEDC850)
        case 1024: return Color(hex: 0xEDC53F)
        case 2048: return Color(hex: 0xEDC22E)
        default: return Color(hex: 0x3C3A32)
        }
    }

    private func tileTextColor(_ value: Int) -> Color {
        value <= 4 ? Color(hex: 0x776E65) : Color(hex: 0xF9F6F2)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragOffset, body: { value, state, _ in
                state = value.translation
            })
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    model.perform(dx > 0 ? .right : .left)
                } else {
                    model.perform(dy > 0 ? .down : .up)
                }
            }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 32, 420)
            let tileSize = (width - spacing * CGFloat(gridSize + 1)) / CGFloat(gridSize)

            VStack(spacing: 16) {
                HStack {
                    Text("2048").font(.system(size: 48, weight: .heavy)).foregroundStyle(Color(hex: 0x776E65))
                    Spacer()
                    VStack(spacing: 4) {
                        Text("SCORE").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: 0xEEE4DA))
                        Text("\(model.score)").font(.system(size: 20, weight: .heavy)).foregroundStyle(.white)
                    }
                    .frame(minWidth: 88)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Color(hex: 0xBBADA0)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)

                HStack {
                    Spacer()
                    Button("New Game") { model.startNewGame() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: 0xF9F6F2))
                        .padding(.vertical, 10).padding(.horizontal, 16)
                        .background(Color(hex: 0x8F7A66))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)

                ZStack {
                    VStack(spacing: spacing) {
                        ForEach(0..<gridSize, id: \.self) { r in
                            HStack(spacing: spacing) {
                                ForEach(0..<gridSize, id: \.self) { c in
                                    let value = model.grid[r][c]
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(tileColor(value))
                                        if value != 0 {
                                            Text("\(value)")
                                                .font(.system(size: value >= 1024 ? 26 : value >= 128 ? 28 : 32, weight: .heavy))
                                                .foregroundStyle(tileTextColor(value))
                                        }
                                    }
                                    .frame(width: tileSize, height: tileSize)
                                }
                            }
                        }
                    }
                    .padding(spacing)
                    .frame(width: width, height: width)
                    .background(Color(hex: 0xBBADA0))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .gesture(swipeGesture)

                    if model.won || model.lost {
                        VStack(spacing: 16) {
                            Text(model.lost ? "Game Over" : "You Win!")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(Color(hex: 0x776E65))
                            HStack(spacing: 12) {
                                Button("New Game") { model.startNewGame() }
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(hex: 0xF9F6F2))
                                    .padding(.vertical, 10).padding(.horizontal, 16)
                                    .background(Color(hex: 0x8F7A66))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                if model.won && !model.lost {
                                    Button("Keep Going") { model.won = false }
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color(hex: 0x8F7A66))
                                        .padding(.vertical, 10).padding(.horizontal, 16)
                                        .background(Color(hex: 0xEEE4DA))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .frame(width: width, height: width)
                        .background(Color(hex: 0xEEE4DA).opacity(0.73))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                VStack(spacing: 8) {
                    Button { model.perform(.up) } label: { Text("↑").font(.system(size: 22, weight: .heavy)) }
                        .buttonStyle(ArrowButtonStyle())
                    HStack(spacing: 12) {
                        Button { model.perform(.left) } label: { Text("←").font(.system(size: 22, weight: .heavy)) }
                            .buttonStyle(ArrowButtonStyle())
                        Button { model.perform(.right) } label: { Text("→").font(.system(size: 22, weight: .heavy)) }
                            .buttonStyle(ArrowButtonStyle())
                    }
                    Button { model.perform(.down) } label: { Text("↓").font(.system(size: 22, weight: .heavy)) }
                        .buttonStyle(ArrowButtonStyle())
                }
            }
            .padding(.vertical, 16)
            .background(Color(hex: 0xFAF8EF))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct ArrowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 56, height: 56)
            .foregroundStyle(Color(hex: 0xF9F6F2))
            .background(Color(hex: 0x8F7A66))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}


