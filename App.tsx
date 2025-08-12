import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import {
  SafeAreaView,
  StyleSheet,
  Text,
  View,
  Pressable,
  Dimensions,
  PanResponder,
  GestureResponderEvent,
  PanResponderGestureState,
} from 'react-native';

type Grid = number[][]; // 0 means empty

const GRID_SIZE = 4;
const TARGET_VALUE = 2048;
const NEW_TILE_PROBABILITY_4 = 0.1; // 10% chance a new tile is 4
const SWIPE_THRESHOLD_PX = 24; // minimum pixels to be considered a swipe

function createEmptyGrid(): Grid {
  return Array.from({ length: GRID_SIZE }, () => Array(GRID_SIZE).fill(0));
}

function cloneGrid(grid: Grid): Grid {
  return grid.map((row) => row.slice());
}

function getEmptyCells(grid: Grid): Array<{ r: number; c: number }> {
  const empty: Array<{ r: number; c: number }> = [];
  for (let r = 0; r < GRID_SIZE; r += 1) {
    for (let c = 0; c < GRID_SIZE; c += 1) {
      if (grid[r][c] === 0) empty.push({ r, c });
    }
  }
  return empty;
}

function addRandomTile(grid: Grid): Grid {
  const empty = getEmptyCells(grid);
  if (empty.length === 0) return grid;
  const { r, c } = empty[Math.floor(Math.random() * empty.length)];
  const value = Math.random() < NEW_TILE_PROBABILITY_4 ? 4 : 2;
  const next = cloneGrid(grid);
  next[r][c] = value;
  return next;
}

function compressRowLeft(row: number[]): { row: number[]; gained: number; moved: boolean } {
  const nonZero = row.filter((x) => x !== 0);
  const compressed: number[] = [];
  let gained = 0;
  for (let i = 0; i < nonZero.length; i += 1) {
    if (i + 1 < nonZero.length && nonZero[i] === nonZero[i + 1]) {
      const merged = nonZero[i] * 2;
      compressed.push(merged);
      gained += merged;
      i += 1; // skip the next one, already merged
    } else {
      compressed.push(nonZero[i]);
    }
  }
  while (compressed.length < GRID_SIZE) compressed.push(0);
  const moved = compressed.some((v, idx) => v !== row[idx]);
  return { row: compressed, gained, moved };
}

function reverseRow(row: number[]): number[] {
  const copy = row.slice();
  copy.reverse();
  return copy;
}

function transpose(grid: Grid): Grid {
  const t = createEmptyGrid();
  for (let r = 0; r < GRID_SIZE; r += 1) {
    for (let c = 0; c < GRID_SIZE; c += 1) {
      t[c][r] = grid[r][c];
    }
  }
  return t;
}

function moveLeft(grid: Grid): { grid: Grid; gained: number; moved: boolean } {
  let moved = false;
  let gained = 0;
  const next = grid.map((row) => {
    const result = compressRowLeft(row);
    moved = moved || result.moved;
    gained += result.gained;
    return result.row;
  });
  return { grid: next, gained, moved };
}

function moveRight(grid: Grid): { grid: Grid; gained: number; moved: boolean } {
  let moved = false;
  let gained = 0;
  const next = grid.map((row) => {
    const reversed = reverseRow(row);
    const result = compressRowLeft(reversed);
    const restored = reverseRow(result.row);
    moved = moved || result.moved;
    gained += result.gained;
    return restored;
  });
  return { grid: next, gained, moved };
}

function moveUp(grid: Grid): { grid: Grid; gained: number; moved: boolean } {
  const t = transpose(grid);
  const movedLeft = moveLeft(t);
  return { grid: transpose(movedLeft.grid), gained: movedLeft.gained, moved: movedLeft.moved };
}

function moveDown(grid: Grid): { grid: Grid; gained: number; moved: boolean } {
  const t = transpose(grid);
  const movedRight = moveRight(t);
  return { grid: transpose(movedRight.grid), gained: movedRight.gained, moved: movedRight.moved };
}

function canMove(grid: Grid): boolean {
  if (getEmptyCells(grid).length > 0) return true;
  // check horizontal merges
  for (let r = 0; r < GRID_SIZE; r += 1) {
    for (let c = 0; c < GRID_SIZE - 1; c += 1) {
      if (grid[r][c] === grid[r][c + 1]) return true;
    }
  }
  // check vertical merges
  for (let c = 0; c < GRID_SIZE; c += 1) {
    for (let r = 0; r < GRID_SIZE - 1; r += 1) {
      if (grid[r][c] === grid[r + 1][c]) return true;
    }
  }
  return false;
}

function hasReachedTarget(grid: Grid): boolean {
  return grid.some((row) => row.some((cell) => cell >= TARGET_VALUE));
}

function getTileBackgroundColor(value: number): string {
  switch (value) {
    case 0:
      return '#cdc1b4';
    case 2:
      return '#eee4da';
    case 4:
      return '#ede0c8';
    case 8:
      return '#f2b179';
    case 16:
      return '#f59563';
    case 32:
      return '#f67c5f';
    case 64:
      return '#f65e3b';
    case 128:
      return '#edcf72';
    case 256:
      return '#edcc61';
    case 512:
      return '#edc850';
    case 1024:
      return '#edc53f';
    case 2048:
      return '#edc22e';
    default:
      return '#3c3a32';
  }
}

function getTileTextColor(value: number): string {
  return value <= 4 ? '#776e65' : '#f9f6f2';
}

function getBoardSize(): number {
  const { width } = Dimensions.get('window');
  const horizontalPadding = 24 * 2; // container padding
  return Math.min(width - horizontalPadding, 420); // cap for tablets
}

export default function App() {
  const [grid, setGrid] = useState<Grid>(() => addRandomTile(addRandomTile(createEmptyGrid())));
  const [score, setScore] = useState<number>(0);
  const [won, setWon] = useState<boolean>(false);
  const [lost, setLost] = useState<boolean>(false);
  

  const boardSize = useMemo(() => getBoardSize(), []);
  const cellGap = 6;
  const cellSize = useMemo(() => (boardSize - cellGap * (GRID_SIZE + 1)) / GRID_SIZE, [boardSize]);

  const performMove = useCallback(
    (direction: 'left' | 'right' | 'up' | 'down') => {
      if (lost) return;
      let result: { grid: Grid; gained: number; moved: boolean };
      switch (direction) {
        case 'left':
          result = moveLeft(grid);
          break;
        case 'right':
          result = moveRight(grid);
          break;
        case 'up':
          result = moveUp(grid);
          break;
        case 'down':
        default:
          result = moveDown(grid);
          break;
      }
      if (!result.moved) return;
      const withNewTile = addRandomTile(result.grid);
      const nextScore = score + result.gained;
      const nextWon = won || hasReachedTarget(withNewTile);
      const nextLost = !canMove(withNewTile);
      setGrid(withNewTile);
      setScore(nextScore);
      setWon(nextWon);
      setLost(nextLost);
    },
    [grid, score, won, lost]
  );

  const startNewGame = useCallback(() => {
    const fresh = addRandomTile(addRandomTile(createEmptyGrid()));
    setGrid(fresh);
    setScore(0);
    setWon(false);
    setLost(false);
  }, []);

  // Keep latest performMove inside a ref to avoid stale closures in PanResponder
  const performMoveRef = useRef<(direction: 'left' | 'right' | 'up' | 'down') => void>(performMove);
  useEffect(() => {
    performMoveRef.current = performMove;
  }, [performMove]);

  const responder = useRef(
    PanResponder.create({
      onMoveShouldSetPanResponder: (_evt: GestureResponderEvent, gesture: PanResponderGestureState) => {
        const absDx = Math.abs(gesture.dx);
        const absDy = Math.abs(gesture.dy);
        return Math.max(absDx, absDy) > SWIPE_THRESHOLD_PX;
      },
      onPanResponderRelease: (_evt: GestureResponderEvent, gesture: PanResponderGestureState) => {
        const { dx, dy } = gesture;
        const absDx = Math.abs(dx);
        const absDy = Math.abs(dy);
        if (Math.max(absDx, absDy) < SWIPE_THRESHOLD_PX) return;
        if (absDx > absDy) {
          performMoveRef.current(dx > 0 ? 'right' : 'left');
        } else {
          performMoveRef.current(dy > 0 ? 'down' : 'up');
        }
      },
    })
  ).current;

  useEffect(() => {
    // if game is over, nothing special here; overlays below render conditionally
  }, [lost, won]);

  interface TileProps { value: number; size: number }

  const Tile: React.FC<TileProps> = ({ value, size }) => (
    <View
      style={[
        styles.tile,
        { width: size, height: size, backgroundColor: getTileBackgroundColor(value) },
      ]}
    >
      {value !== 0 && (
        <Text style={[styles.tileText, { color: getTileTextColor(value), fontSize: value >= 1024 ? 26 : value >= 128 ? 28 : 32 }]}>
          {value}
        </Text>
      )}
    </View>
  );

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar style="dark" />
      <View style={styles.container} {...responder.panHandlers}>
        <View style={styles.headerRow}>
          <Text style={styles.title}>2048</Text>
          <View style={styles.scoreRow}>
            <View style={styles.scoreBox}>
              <Text style={styles.scoreLabel}>SCORE</Text>
              <Text style={styles.scoreValue}>{score}</Text>
            </View>
          </View>
        </View>
        <View style={styles.controlsRow}>
          <Pressable style={styles.newGameButton} onPress={startNewGame} accessibilityRole="button">
            <Text style={styles.newGameText}>New Game</Text>
          </Pressable>
        </View>

        <View
          style={[styles.board, { width: boardSize, height: boardSize, padding: cellGap, gap: cellGap }]}
        >
          {grid.map((row, rIdx) => (
            <View key={`row-${rIdx}`} style={[styles.row, { gap: cellGap }]}> 
              {row.map((value, cIdx) => (
                <Tile key={`cell-${rIdx}-${cIdx}`} value={value} size={cellSize} />
              ))}
            </View>
          ))}

          {(won || lost) && (
            <View style={[styles.overlay, { width: boardSize, height: boardSize }]}> 
              <View style={styles.overlayBox}>
                <Text style={styles.overlayTitle}>{lost ? 'Game Over' : 'You Win!'}</Text>
                <View style={styles.overlayButtonsRow}>
                  <Pressable style={styles.overlayButtonPrimary} onPress={startNewGame}>
                    <Text style={styles.overlayButtonPrimaryText}>New Game</Text>
                  </Pressable>
                  {won && !lost && (
                    <Pressable style={styles.overlayButtonSecondary} onPress={() => setWon(false)}>
                      <Text style={styles.overlayButtonSecondaryText}>Keep Going</Text>
                    </Pressable>
                  )}
                </View>
              </View>
            </View>
          )}
        </View>
    </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#faf8ef',
  },
  container: {
    flex: 1,
    alignItems: 'center',
    paddingHorizontal: 24,
    gap: 16,
  },
  headerRow: {
    width: '100%',
    marginTop: 8,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: {
    fontSize: 48,
    fontWeight: '800',
    color: '#776e65',
  },
  scoreRow: {
    flexDirection: 'row',
    gap: 10,
  },
  scoreBox: {
    backgroundColor: '#bbada0',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    alignItems: 'center',
    minWidth: 88,
  },
  scoreLabel: {
    color: '#eee4da',
    fontSize: 12,
    fontWeight: '700',
  },
  scoreValue: {
    color: '#ffffff',
    fontSize: 20,
    fontWeight: '800',
  },
  controlsRow: {
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  newGameButton: {
    backgroundColor: '#8f7a66',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  newGameText: {
    color: '#f9f6f2',
    fontWeight: '700',
    fontSize: 16,
  },
  board: {
    position: 'relative',
    backgroundColor: '#bbada0',
    borderRadius: 12,
    justifyContent: 'center',
  },
  row: {
    flexDirection: 'row',
  },
  tile: {
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tileText: {
    fontWeight: '800',
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(238, 228, 218, 0.73)',
    borderRadius: 12,
  },
  overlayBox: {
    alignItems: 'center',
    gap: 16,
  },
  overlayTitle: {
    fontSize: 36,
    fontWeight: '800',
    color: '#776e65',
  },
  overlayButtonsRow: {
    flexDirection: 'row',
    gap: 12,
  },
  overlayButtonPrimary: {
    backgroundColor: '#8f7a66',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  overlayButtonPrimaryText: {
    color: '#f9f6f2',
    fontWeight: '700',
    fontSize: 16,
  },
  overlayButtonSecondary: {
    backgroundColor: '#eee4da',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  overlayButtonSecondaryText: {
    color: '#8f7a66',
    fontWeight: '700',
    fontSize: 16,
  },
});
