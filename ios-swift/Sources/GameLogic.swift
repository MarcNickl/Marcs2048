import Foundation
import UIKit

struct Position: Hashable { let row: Int; let col: Int }

struct MoveResult {
    var grid: [[Int]]
    var gained: Int
    var moved: Bool
}

final class GameModel: ObservableObject {
    static let gridSize = 4
    static let target = 2048
    static let probFour = 0.1

    @Published var grid: [[Int]] = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
    @Published var score: Int = 0
    @Published var won: Bool = false
    @Published var lost: Bool = false
    private var lastState: (grid: [[Int]], score: Int)? = nil

    init() {
        startNewGame()
    }

    func startNewGame() {
        grid = Array(repeating: Array(repeating: 0, count: GameModel.gridSize), count: GameModel.gridSize)
        score = 0
        won = false
        lost = false
        lastState = nil
        grid = addRandomTile(grid)
        grid = addRandomTile(grid)
    }

    func perform(_ direction: Direction, hapticsEnabled: Bool = true, strongHapticsEnabled: Bool = true) {
        guard !lost else { return }
        let result: MoveResult
        switch direction {
        case .left:
            result = moveLeft(grid)
        case .right:
            result = moveRight(grid)
        case .up:
            result = moveUp(grid)
        case .down:
            result = moveDown(grid)
        }
        guard result.moved else { return }
        lastState = (grid, score)
        var g = result.grid
        g = addRandomTile(g)
        score += result.gained
        won = won || hasReachedTarget(g)
        lost = !canMove(g)
        grid = g

        // Haptics
        if hapticsEnabled {
            if result.gained > 0 {
                let useStrongHaptic = strongHapticsEnabled && result.gained >= 64
                let style: UIImpactFeedbackGenerator.FeedbackStyle = useStrongHaptic ? .medium : .light
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
            if won {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else if lost {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    func undo() {
        guard let last = lastState else { return }
        grid = last.grid
        score = last.score
        won = false
        lost = false
        lastState = nil
    }
}

enum Direction { case left, right, up, down }

// MARK: - Helpers

private func emptyCells(_ grid: [[Int]]) -> [Position] {
    var out: [Position] = []
    for r in 0..<GameModel.gridSize {
        for c in 0..<GameModel.gridSize {
            if grid[r][c] == 0 { out.append(Position(row: r, col: c)) }
        }
    }
    return out
}

private func addRandomTile(_ grid: [[Int]]) -> [[Int]] {
    var next = grid
    let empties = emptyCells(grid)
    guard !empties.isEmpty else { return grid }
    let pos = empties.randomElement()!
    next[pos.row][pos.col] = Double.random(in: 0..<1) < GameModel.probFour ? 4 : 2
    return next
}

private func compressRowLeft(_ row: [Int]) -> (row: [Int], gained: Int, moved: Bool) {
    let nonZero = row.filter { $0 != 0 }
    var compressed: [Int] = []
    var gained = 0
    var i = 0
    while i < nonZero.count {
        if i + 1 < nonZero.count && nonZero[i] == nonZero[i+1] {
            let merged = nonZero[i] * 2
            compressed.append(merged)
            gained += merged
            i += 2
        } else {
            compressed.append(nonZero[i])
            i += 1
        }
    }
    while compressed.count < GameModel.gridSize { compressed.append(0) }
    let moved = zip(compressed, row).contains { $0 != $1 }
    return (compressed, gained, moved)
}

private func reverseRow(_ row: [Int]) -> [Int] { row.reversed() }

private func transpose(_ grid: [[Int]]) -> [[Int]] {
    var t = Array(repeating: Array(repeating: 0, count: GameModel.gridSize), count: GameModel.gridSize)
    for r in 0..<GameModel.gridSize {
        for c in 0..<GameModel.gridSize { t[c][r] = grid[r][c] }
    }
    return t
}

private func moveLeft(_ grid: [[Int]]) -> MoveResult {
    var moved = false
    var gained = 0
    let next = grid.map { row -> [Int] in
        let res = compressRowLeft(row)
        moved = moved || res.moved
        gained += res.gained
        return res.row
    }
    return MoveResult(grid: next, gained: gained, moved: moved)
}

private func moveRight(_ grid: [[Int]]) -> MoveResult {
    var moved = false
    var gained = 0
    let next = grid.map { row -> [Int] in
        let res = compressRowLeft(reverseRow(row))
        let restored = reverseRow(res.row)
        moved = moved || res.moved
        gained += res.gained
        return Array(restored)
    }
    return MoveResult(grid: next, gained: gained, moved: moved)
}

private func moveUp(_ grid: [[Int]]) -> MoveResult {
    let t = transpose(grid)
    let m = moveLeft(t)
    return MoveResult(grid: transpose(m.grid), gained: m.gained, moved: m.moved)
}

private func moveDown(_ grid: [[Int]]) -> MoveResult {
    let t = transpose(grid)
    let m = moveRight(t)
    return MoveResult(grid: transpose(m.grid), gained: m.gained, moved: m.moved)
}

private func canMove(_ grid: [[Int]]) -> Bool {
    if !emptyCells(grid).isEmpty { return true }
    for r in 0..<GameModel.gridSize {
        for c in 0..<(GameModel.gridSize - 1) {
            if grid[r][c] == grid[r][c+1] { return true }
        }
    }
    for c in 0..<GameModel.gridSize {
        for r in 0..<(GameModel.gridSize - 1) {
            if grid[r][c] == grid[r+1][c] { return true }
        }
    }
    return false
}

private func hasReachedTarget(_ grid: [[Int]]) -> Bool {
    for r in 0..<GameModel.gridSize {
        for c in 0..<GameModel.gridSize {
            if grid[r][c] >= GameModel.target { return true }
        }
    }
    return false
}


